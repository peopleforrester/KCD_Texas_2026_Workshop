#!/bin/bash
# batch-provision.sh
# Provisions multiple EKS clusters for workshop attendees.
# Each attendee gets their own isolated cluster.
#
# Usage: ./batch-provision.sh <attendee-count> [region]
# Example: ./batch-provision.sh 30 us-east-2
#
# COST WARNING:
#   Each cluster costs ~$0.76/hr (EKS + 3x t3.xlarge)
#   30 clusters for 3 hours = ~$68
#   50 clusters for 3 hours = ~$114
#   DESTROY IMMEDIATELY AFTER THE WORKSHOP.

set -euo pipefail

ATTENDEE_COUNT="${1:?Usage: ./batch-provision.sh <attendee-count> [region]}"
REGION="${2:-us-east-2}"
TERRAFORM_DIR="$(cd "$(dirname "$0")/terraform" && pwd)"
OUTPUT_DIR="$(cd "$(dirname "$0")" && pwd)/attendee-configs"

mkdir -p "${OUTPUT_DIR}"

echo "============================================="
echo "KCD Texas Workshop - Batch Provisioning"
echo "Attendees:  ${ATTENDEE_COUNT}"
echo "Region:     ${REGION}"
echo "Cost est:   ~\$$(echo "${ATTENDEE_COUNT} * 0.76 * 3" | bc)/3hrs"
echo "============================================="
echo ""
echo "This will create ${ATTENDEE_COUNT} EKS clusters."
echo "Press Ctrl+C within 10 seconds to abort."
sleep 10

# Track results
SUCCESSES=0
FAILURES=0
FAILED_CLUSTERS=""

for i in $(seq -w 1 "${ATTENDEE_COUNT}"); do
  CLUSTER_NAME="kcd-texas-attendee-${i}"
  WORKSPACE="attendee-${i}"
  
  echo ""
  echo "--- Provisioning cluster ${i}/${ATTENDEE_COUNT}: ${CLUSTER_NAME} ---"
  
  cd "${TERRAFORM_DIR}"
  
  # Use Terraform workspaces to isolate state per attendee
  terraform workspace new "${WORKSPACE}" 2>/dev/null || terraform workspace select "${WORKSPACE}"
  
  if terraform apply \
    -var="cluster_name=${CLUSTER_NAME}" \
    -var="region=${REGION}" \
    -auto-approve \
    -compact-warnings 2>&1 | tee "${OUTPUT_DIR}/${CLUSTER_NAME}-provision.log"; then
    
    # Run post-provision setup
    cd "$(dirname "$0")"
    if bash post-provision-setup.sh "${CLUSTER_NAME}" "${REGION}" 2>&1 | tee -a "${OUTPUT_DIR}/${CLUSTER_NAME}-provision.log"; then
      
      # Generate attendee connection card
      ENDPOINT=$(cd "${TERRAFORM_DIR}" && terraform output -raw cluster_endpoint 2>/dev/null)
      cat > "${OUTPUT_DIR}/${CLUSTER_NAME}-connection.txt" <<CARD
KCD Texas 2026 Workshop
========================
Your Cluster: ${CLUSTER_NAME}
Region: ${REGION}
Endpoint: ${ENDPOINT}

Connect:
  aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
  kubectl get nodes

Workshop Repo:
  git clone <REPO_URL>
  cd kcd-texas-workshop

Start Building:
  claude --dangerously-skip-permissions -p "Read CLAUDE.md and BUILD-SPEC.md. Build all phases sequentially."

CARD
      
      SUCCESSES=$((SUCCESSES + 1))
      echo "  Cluster ${CLUSTER_NAME} READY"
    else
      FAILURES=$((FAILURES + 1))
      FAILED_CLUSTERS="${FAILED_CLUSTERS} ${CLUSTER_NAME}"
      echo "  WARNING: Post-provision setup failed for ${CLUSTER_NAME}"
    fi
  else
    FAILURES=$((FAILURES + 1))
    FAILED_CLUSTERS="${FAILED_CLUSTERS} ${CLUSTER_NAME}"
    echo "  ERROR: Terraform apply failed for ${CLUSTER_NAME}"
  fi
done

echo ""
echo "============================================="
echo "Batch Provisioning Complete"
echo "Succeeded: ${SUCCESSES}/${ATTENDEE_COUNT}"
echo "Failed:    ${FAILURES}/${ATTENDEE_COUNT}"
if [ -n "${FAILED_CLUSTERS}" ]; then
  echo "Failed clusters: ${FAILED_CLUSTERS}"
fi
echo ""
echo "Connection cards in: ${OUTPUT_DIR}/"
echo ""
echo "REMEMBER: Run batch-teardown.sh IMMEDIATELY after the workshop."
echo "============================================="
