#!/bin/bash
# teardown.sh
# Destroys the workshop cluster and all associated AWS resources.
# Run this IMMEDIATELY after the workshop to stop burning money.
#
# Usage: ./teardown.sh [cluster-name] [region]
# Example: ./teardown.sh kcd-texas-workshop us-east-2

set -euo pipefail

CLUSTER_NAME="${1:-kcd-texas-workshop}"
REGION="${2:-us-east-2}"

echo "============================================="
echo "KCD Texas Workshop - TEARDOWN"
echo "Cluster: ${CLUSTER_NAME}"
echo "Region:  ${REGION}"
echo "============================================="
echo ""
echo "WARNING: This will destroy the EKS cluster, VPC, and all workshop resources."
echo "Press Ctrl+C within 10 seconds to abort."
sleep 10

# -----------------------------------------------
# 1. Delete workshop resources that might block Terraform destroy
#    (LoadBalancer services create ENIs and ELBs outside Terraform)
# -----------------------------------------------
echo ""
echo "[1/3] Cleaning up Kubernetes resources that may block teardown..."

# Update kubeconfig in case it's stale
aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}" 2>/dev/null || true

# Delete all LoadBalancer services (they create AWS ELBs outside Terraform)
kubectl get svc --all-namespaces -o json 2>/dev/null | \
  jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read -r NS SVC; do
    echo "  Deleting LoadBalancer service: ${NS}/${SVC}"
    kubectl delete svc "${SVC}" -n "${NS}" --timeout=60s 2>/dev/null || true
  done

# Delete all PVCs (they create EBS volumes outside Terraform)
kubectl delete pvc --all --all-namespaces --timeout=60s 2>/dev/null || true

echo "  Waiting 30 seconds for AWS resources to detach..."
sleep 30

# -----------------------------------------------
# 2. Terraform destroy
# -----------------------------------------------
echo ""
echo "[2/3] Running terraform destroy..."
cd "$(dirname "$0")/terraform"

terraform destroy \
  -var="cluster_name=${CLUSTER_NAME}" \
  -var="region=${REGION}" \
  -auto-approve

echo "  Terraform destroy complete"

# -----------------------------------------------
# 3. Verify cleanup
# -----------------------------------------------
echo ""
echo "[3/3] Verifying cleanup..."

# Check for orphaned resources
REMAINING_VPCS=$(aws ec2 describe-vpcs --region "${REGION}" \
  --filters "Name=tag:Project,Values=kcd-texas-*" \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null || true)

if [ -n "${REMAINING_VPCS}" ] && [ "${REMAINING_VPCS}" != "None" ]; then
  echo "  WARNING: Orphaned VPCs found: ${REMAINING_VPCS}"
  echo "  You may need to delete these manually in the AWS console."
else
  echo "  No orphaned VPCs found"
fi

REMAINING_CLUSTERS=$(aws eks list-clusters --region "${REGION}" \
  --query "clusters[?starts_with(@, 'kcd-texas')]" --output text 2>/dev/null || true)

if [ -n "${REMAINING_CLUSTERS}" ] && [ "${REMAINING_CLUSTERS}" != "None" ]; then
  echo "  WARNING: Orphaned EKS clusters found: ${REMAINING_CLUSTERS}"
else
  echo "  No orphaned EKS clusters found"
fi

echo ""
echo "============================================="
echo "Teardown complete."
echo "Check your AWS bill in 24 hours to confirm all resources are gone."
echo "============================================="
