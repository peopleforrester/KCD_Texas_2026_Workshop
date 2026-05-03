#!/bin/bash
# batch-teardown.sh
# Destroys ALL attendee EKS clusters.
# Run this IMMEDIATELY after the workshop ends.
#
# Usage: ./batch-teardown.sh <attendee-count> [region]
# Example: ./batch-teardown.sh 30 us-east-2

set -euo pipefail

ATTENDEE_COUNT="${1:?Usage: ./batch-teardown.sh <attendee-count> [region]}"
REGION="${2:-us-east-2}"
TERRAFORM_DIR="$(cd "$(dirname "$0")/terraform" && pwd)"

echo "============================================="
echo "KCD Texas Workshop - BATCH TEARDOWN"
echo "Destroying ${ATTENDEE_COUNT} clusters"
echo "============================================="
echo ""
echo "WARNING: This will destroy ALL attendee clusters."
echo "Press Ctrl+C within 10 seconds to abort."
sleep 10

DESTROYED=0
FAILED=0

for i in $(seq -w 1 "${ATTENDEE_COUNT}"); do
  CLUSTER_NAME="kcd-texas-attendee-${i}"
  WORKSPACE="attendee-${i}"
  
  echo ""
  echo "--- Destroying cluster ${i}/${ATTENDEE_COUNT}: ${CLUSTER_NAME} ---"
  
  cd "${TERRAFORM_DIR}"
  
  # Select workspace
  terraform workspace select "${WORKSPACE}" 2>/dev/null || {
    echo "  Workspace ${WORKSPACE} not found, skipping"
    continue
  }
  
  # Clean up k8s resources that block terraform destroy
  aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}" 2>/dev/null || true
  kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer --timeout=30s 2>/dev/null || true
  kubectl delete pvc --all --all-namespaces --timeout=30s 2>/dev/null || true
  sleep 5
  
  if terraform destroy \
    -var="cluster_name=${CLUSTER_NAME}" \
    -var="region=${REGION}" \
    -auto-approve \
    -compact-warnings 2>&1; then
    
    DESTROYED=$((DESTROYED + 1))
    
    # Clean up workspace
    terraform workspace select default
    terraform workspace delete "${WORKSPACE}" 2>/dev/null || true
    
    echo "  Cluster ${CLUSTER_NAME} DESTROYED"
  else
    FAILED=$((FAILED + 1))
    echo "  ERROR: Failed to destroy ${CLUSTER_NAME}. Manual cleanup required."
  fi
done

echo ""
echo "============================================="
echo "Batch Teardown Complete"
echo "Destroyed: ${DESTROYED}/${ATTENDEE_COUNT}"
echo "Failed:    ${FAILED}/${ATTENDEE_COUNT}"
if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "MANUAL CLEANUP REQUIRED for failed clusters."
  echo "Check the AWS console for orphaned resources tagged Project=kcd-texas-*"
fi
echo "============================================="
