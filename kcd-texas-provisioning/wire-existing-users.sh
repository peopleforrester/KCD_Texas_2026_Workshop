#!/usr/bin/env bash
# ABOUTME: Wire existing kcd-tx-attendee-NN IAM users to their matching EKS clusters.
# ABOUTME: Creates a 2nd access key per user, EKS Access Entry, writes pool.csv directly to ../kcd-website/.
#
# State this script assumes (verified via discovery on 2026-05-15):
#   - 60 EKS clusters ACTIVE: kcd-tx-attendee-01 .. kcd-tx-attendee-60 in us-east-2
#   - 60 matching IAM users exist with 1 active access key each
#   - 0 of those users have an EKS Access Entry on their matching cluster
#   - AWS keys' secrets are cryptographically lost from the AWS side (only the
#     access-key-id is visible; secret was emitted at creation time only)
#
# What this script does, per user:
#   1. aws iam create-access-key       → creates a 2ND key (AWS allows 2/user).
#                                        Leaves the existing key untouched.
#                                        Captures the new SecretAccessKey
#                                        (only moment it's visible).
#   2. aws eks create-access-entry     → maps user/kcd-tx-attendee-NN to
#                                        cluster kcd-tx-attendee-NN.
#                                        Idempotent: skips if entry exists.
#   3. aws eks associate-access-policy → grants AmazonEKSClusterAdminPolicy
#                                        on the user's own cluster only.
#                                        Idempotent server-side.
#   4. Append a row to ../kcd-website/pool.csv with name, key_id, secret, region.
#
# What this script does NOT do:
#   - Create the permissions boundary policy (intentionally skipped per
#     instruction — existing users have minimal kubeconfig-only inline policy;
#     boundary is defense-in-depth not required to function)
#   - Delete the existing 1st access key (Accenture's process may still be
#     using it for monitoring; we don't touch what they made)
#   - Push to Railway / restart the kcd-website app (separate concern; the
#     deploy will be done by other Claude Code session)
#
# Usage:
#   AWS_PROFILE=kcd-instructor bash kcd-texas-provisioning/wire-existing-users.sh
#   AWS_PROFILE=kcd-instructor bash kcd-texas-provisioning/wire-existing-users.sh 10  # only first 10
#
# Re-run safety: the IAM create-access-key step is NOT idempotent — running
# twice will fail when AWS rejects the 3rd key (cap is 2 per user). If you
# need to re-run, delete the previously-created keys from the failed run
# first. The EKS steps are idempotent and safe to re-run.

set -euo pipefail

NUM_USERS="${1:-60}"
REGION="${REGION:-us-east-2}"
ACCOUNT_ID="${ACCOUNT_ID:-771128797125}"
POOL_CSV="${POOL_CSV:-../kcd-website/pool.csv}"
ADMIN_POLICY_ARN="arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/kcd-texas-provisioning/attendee-configs"
POOL_CSV_PATH="$(cd "${REPO_ROOT}" && cd "$(dirname "${POOL_CSV}")" && pwd)/$(basename "${POOL_CSV}")"

mkdir -p "${LOG_DIR}"

# ─── Pre-flight ────────────────────────────────────────────────────────────
echo "──────────────────────────────────────────────────────────────────────────"
echo "  Wire existing IAM users → EKS clusters → pool.csv"
echo "  users:        kcd-tx-attendee-01 .. kcd-tx-attendee-$(printf '%02d' "${NUM_USERS}")"
echo "  region:       ${REGION}"
echo "  expected acct: ${ACCOUNT_ID}"
echo "  pool.csv →    ${POOL_CSV_PATH}"
echo "  per-user logs ${LOG_DIR}/"
echo "──────────────────────────────────────────────────────────────────────────"
echo

CURRENT_ACCOUNT="$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || true)"
if [[ "${CURRENT_ACCOUNT}" != "${ACCOUNT_ID}" ]]; then
    printf "ERROR: authed account is '%s', expected '%s'\n" "${CURRENT_ACCOUNT}" "${ACCOUNT_ID}" >&2
    printf "       export AWS_PROFILE=kcd-instructor and try again\n" >&2
    exit 1
fi
echo "  ✓ authed as $(aws sts get-caller-identity --query 'Arn' --output text)"
echo

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq required but not on PATH" >&2
    exit 1
fi

# ─── pool.csv header ───────────────────────────────────────────────────────
if [[ ! -d "$(dirname "${POOL_CSV_PATH}")" ]]; then
    printf "ERROR: directory '%s' does not exist\n" "$(dirname "${POOL_CSV_PATH}")" >&2
    exit 1
fi
echo "name,access_key,secret_key,region" > "${POOL_CSV_PATH}"
echo "  ✓ wrote pool.csv header"
echo

# ─── Loop ──────────────────────────────────────────────────────────────────
SUCCESSES=0
FAILURES=()

for i in $(seq -w 1 "${NUM_USERS}"); do
    USER_NAME="kcd-tx-attendee-${i}"
    CLUSTER_NAME="kcd-tx-attendee-${i}"
    USER_ARN="arn:aws:iam::${ACCOUNT_ID}:user/${USER_NAME}"
    LOG_FILE="${LOG_DIR}/${USER_NAME}-wire.log"

    printf '  [%s] ' "${USER_NAME}"

    {
        echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) wiring ${USER_NAME} → ${CLUSTER_NAME} ==="
    } > "${LOG_FILE}"

    # ── Step 1: create a 2nd access key ────────────────────────────────────
    KEY_JSON="$(aws iam create-access-key --user-name "${USER_NAME}" --output json 2>>"${LOG_FILE}" || true)"
    if [[ -z "${KEY_JSON}" ]] || ! echo "${KEY_JSON}" | jq -e '.AccessKey.AccessKeyId' >/dev/null 2>&1; then
        echo "FAIL — create-access-key (see ${LOG_FILE})"
        FAILURES+=("${USER_NAME}:create-access-key")
        continue
    fi
    AK_ID="$(echo "${KEY_JSON}" | jq -r '.AccessKey.AccessKeyId')"
    AK_SECRET="$(echo "${KEY_JSON}" | jq -r '.AccessKey.SecretAccessKey')"
    echo "  new access key id: ${AK_ID}" >> "${LOG_FILE}"

    # ── Step 2: create EKS Access Entry (idempotent) ───────────────────────
    if aws eks describe-access-entry \
            --cluster-name "${CLUSTER_NAME}" \
            --principal-arn "${USER_ARN}" \
            --region "${REGION}" >/dev/null 2>&1; then
        echo "  access entry already exists" >> "${LOG_FILE}"
    else
        if ! aws eks create-access-entry \
                --cluster-name "${CLUSTER_NAME}" \
                --principal-arn "${USER_ARN}" \
                --type STANDARD \
                --username "${USER_NAME}" \
                --region "${REGION}" >/dev/null 2>>"${LOG_FILE}"; then
            echo "FAIL — create-access-entry (see ${LOG_FILE})"
            FAILURES+=("${USER_NAME}:create-access-entry")
            continue
        fi
        echo "  access entry created" >> "${LOG_FILE}"
    fi

    # ── Step 3: associate AmazonEKSClusterAdminPolicy ──────────────────────
    if ! aws eks associate-access-policy \
            --cluster-name "${CLUSTER_NAME}" \
            --principal-arn "${USER_ARN}" \
            --policy-arn "${ADMIN_POLICY_ARN}" \
            --access-scope type=cluster \
            --region "${REGION}" >/dev/null 2>>"${LOG_FILE}"; then
        # associate-access-policy is idempotent server-side; the redundant
        # call returns success on retry. A real failure is unusual.
        echo "FAIL — associate-access-policy (see ${LOG_FILE})"
        FAILURES+=("${USER_NAME}:associate-access-policy")
        continue
    fi
    echo "  AmazonEKSClusterAdminPolicy associated" >> "${LOG_FILE}"

    # ── Step 4: append to pool.csv (secret never lands in the per-user log) ─
    echo "${USER_NAME},${AK_ID},${AK_SECRET},${REGION}" >> "${POOL_CSV_PATH}"

    SUCCESSES=$((SUCCESSES + 1))
    printf 'OK  (key %s)\n' "${AK_ID}"
done

# ─── Summary ───────────────────────────────────────────────────────────────
echo
echo "──────────────────────────────────────────────────────────────────────────"
echo "  Summary: ${SUCCESSES}/${NUM_USERS} wired"
if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo "  Failures (${#FAILURES[@]}):"
    for f in "${FAILURES[@]}"; do
        echo "    - ${f}"
    done
    echo
    echo "  Per-user logs at: ${LOG_DIR}/"
fi
POOL_ROWS=$(($(wc -l < "${POOL_CSV_PATH}") - 1))   # subtract header
echo "  pool.csv: ${POOL_ROWS} data rows at ${POOL_CSV_PATH}"
echo "──────────────────────────────────────────────────────────────────────────"

# ─── Sanity test attendee-01 ────────────────────────────────────────────────
if [[ ${SUCCESSES} -lt 1 ]]; then
    echo "No successes — skipping sanity test"
    exit 1
fi

echo
echo "──────────────────────────────────────────────────────────────────────────"
echo "  Sanity test: kcd-tx-attendee-01 keys → cluster kcd-tx-attendee-01"
echo "──────────────────────────────────────────────────────────────────────────"

# Read row 2 (header is row 1) for attendee-01
ROW="$(sed -n '2p' "${POOL_CSV_PATH}")"
T_NAME="$(echo "${ROW}" | cut -d',' -f1)"
T_KEY="$(echo "${ROW}" | cut -d',' -f2)"
T_SECRET="$(echo "${ROW}" | cut -d',' -f3)"
T_REGION="$(echo "${ROW}" | cut -d',' -f4)"

if [[ "${T_NAME}" != "kcd-tx-attendee-01" ]]; then
    echo "WARN — first pool.csv row is '${T_NAME}', not kcd-tx-attendee-01; skipping sanity test"
    exit 0
fi

# Isolate the test — don't touch the user's default kubeconfig or AWS env
SANITY_KUBECONFIG="$(mktemp -t kcd-sanity-XXXXXX.kubeconfig)"
trap 'rm -f "${SANITY_KUBECONFIG}"' EXIT

set +e
# `env -u AWS_PROFILE` unsets the profile entirely; setting AWS_PROFILE="" makes
# the CLI look up a literal empty-string profile name and fail.
env -u AWS_PROFILE \
KUBECONFIG="${SANITY_KUBECONFIG}" \
AWS_ACCESS_KEY_ID="${T_KEY}" \
AWS_SECRET_ACCESS_KEY="${T_SECRET}" \
    aws eks update-kubeconfig --name "${T_NAME}" --region "${T_REGION}" 2>&1 | sed 's/^/  /'

env -u AWS_PROFILE \
KUBECONFIG="${SANITY_KUBECONFIG}" \
AWS_ACCESS_KEY_ID="${T_KEY}" \
AWS_SECRET_ACCESS_KEY="${T_SECRET}" \
    kubectl get nodes 2>&1 | sed 's/^/  /'
RC=$?
set -e

echo
if [[ ${RC} -eq 0 ]]; then
    echo "  ✓ SANITY TEST PASSED — attendee-01 keys authenticate, kubectl returns nodes"
else
    echo "  ✗ SANITY TEST FAILED — kubectl exit=${RC}"
    echo "    Check ${LOG_DIR}/kcd-tx-attendee-01-wire.log"
    exit 1
fi

# ─── Next steps (printed for the operator, not executed) ───────────────────
echo
echo "──────────────────────────────────────────────────────────────────────────"
echo "  Next steps (you do these — this script will NOT touch the kcd-website app):"
echo "──────────────────────────────────────────────────────────────────────────"
echo
echo "  1. Verify pool.csv looks right (60 rows):"
echo "       wc -l ${POOL_CSV_PATH}"
echo "       head -3 ${POOL_CSV_PATH}"
echo
echo "  2. Deploy kcd-website to Railway from the other Claude Code session."
echo "     The app's seed step inserts pool.csv rows into pool.db only when"
echo "     the table is empty, so you'll need to clear the previous seed:"
echo "       (in ../kcd-website/) railway up"
echo "       (Railway exec)        rm /data/pool.db"
echo "       (Railway dashboard)   restart the service"
echo
echo "  3. Smoke-test by submitting a test email to the registration page"
echo "     and confirming the success page hands back a real cluster row."
echo
