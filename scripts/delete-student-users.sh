#!/usr/bin/env bash
# ABOUTME: Deletes all workshop student IAM users, access keys, and inline policies.
# ABOUTME: Run after workshop teardown. Optionally removes the permissions boundary policy.

set -euo pipefail

STUDENT_COUNT="${1:?Usage: $0 <student_count> [--delete-boundary]}"
DELETE_BOUNDARY="${2:-}"
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
CLUSTER_PREFIX="kcd-texas-student"

echo "============================================"
echo "Deleting $STUDENT_COUNT student IAM users"
echo "Account: $ACCOUNT_ID"
echo "============================================"

DELETED=0
NOT_FOUND=0

for i in $(seq -w 1 "$STUDENT_COUNT"); do
    USER="${CLUSTER_PREFIX}-${i}"

    if ! aws iam get-user --user-name "$USER" &>/dev/null; then
        echo "  $USER: not found, skipping."
        NOT_FOUND=$((NOT_FOUND + 1))
        continue
    fi

    # Delete access keys
    for KEY in $(aws iam list-access-keys --user-name "$USER" --query 'AccessKeyMetadata[*].AccessKeyId' --output text 2>/dev/null); do
        aws iam delete-access-key --user-name "$USER" --access-key-id "$KEY"
    done

    # Delete inline policies
    for POLICY in $(aws iam list-user-policies --user-name "$USER" --query 'PolicyNames[*]' --output text 2>/dev/null); do
        aws iam delete-user-policy --user-name "$USER" --policy-name "$POLICY"
    done

    # Delete user
    aws iam delete-user --user-name "$USER"
    echo "  $USER: deleted."
    DELETED=$((DELETED + 1))
done

echo ""
echo "Deleted: $DELETED  |  Not found: $NOT_FOUND"

# Optionally delete the permissions boundary policy
if [ "$DELETE_BOUNDARY" = "--delete-boundary" ]; then
    BOUNDARY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/kcd-texas-student-boundary"
    echo ""
    echo "Deleting permissions boundary: $BOUNDARY_ARN"
    aws iam delete-policy --policy-arn "$BOUNDARY_ARN" 2>/dev/null && \
        echo "  Deleted." || \
        echo "  Could not delete (may still be attached to users)."
fi

echo ""
echo "Done. Verify with:"
echo "  aws iam list-users --query 'Users[?starts_with(UserName, \`kcd-texas-student\`)].UserName' --output text"
