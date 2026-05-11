#!/usr/bin/env bash
# batch-provision.sh
# Provisions multiple EKS clusters for workshop attendees.
# Each attendee gets their own isolated cluster.
#
# Usage: ./batch-provision.sh <attendee-count> [region]
# Example: ./batch-provision.sh 30 us-east-2
#
# COST WARNING:
#   Each cluster costs ~$0.65/hr:
#     EKS control plane $0.10 + 3x t3.xlarge $0.50 + NAT Gateway $0.045 + EIP $0.005
#   30 clusters for 3 hours = ~$59
#   64 clusters for 3 hours = ~$125
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
echo "Cost est:   ~\$$(echo "${ATTENDEE_COUNT} * 0.65 * 3" | bc)/3hrs"
echo "============================================="
echo ""
echo "This will create ${ATTENDEE_COUNT} EKS clusters."
echo ""
read -r -p "Type 'PROVISION ${ATTENDEE_COUNT}' to confirm: " CONFIRM
if [ "${CONFIRM}" != "PROVISION ${ATTENDEE_COUNT}" ]; then
  echo "Aborted."
  exit 0
fi

# Track results
SUCCESSES=0
FAILURES=0
FAILED_CLUSTERS=""

for i in $(seq -w 1 "${ATTENDEE_COUNT}"); do
  CLUSTER_NAME="kcd-texas-student-${i}"
  WORKSPACE="student-${i}"
  
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
================================================================
KCD Texas 2026 -- "The 90-Minute IDP" -- Connection Card

Cluster:        ${CLUSTER_NAME}
Region:         ${REGION}
Endpoint:       ${ENDPOINT}

Connect:
  aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
  kubectl get nodes

Workshop repo:  https://github.com/peopleforrester/KCD_Texas_2026_Workshop
  git clone https://github.com/peopleforrester/KCD_Texas_2026_Workshop.git ~/kcd-texas-workshop
  cd ~/kcd-texas-workshop

Start the workshop:
  claude
  # Then follow kcd-texas-student-playbook.md, starting at "Before You Start".

If you get stuck, raise your hand.  TAs are circulating.
================================================================
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
echo "NEXT: provision the presenter cluster and 3 spares (not handled by this script):"
echo "  cd \"\$(dirname \"\$0\")/terraform\""
echo "  terraform workspace new presenter || terraform workspace select presenter"
echo "  terraform apply -var=\"cluster_name=kcd-texas-presenter\" -var=\"region=${REGION}\" -auto-approve"
echo "  cd .. && bash post-provision-setup.sh kcd-texas-presenter \"${REGION}\""
echo "  for i in 01 02 03; do"
echo "    cd \"\$(dirname \"\$0\")/terraform\""
echo "    terraform workspace new \"spare-\$i\" || terraform workspace select \"spare-\$i\""
echo "    terraform apply -var=\"cluster_name=kcd-texas-spare-\$i\" -var=\"region=${REGION}\" -auto-approve"
echo "    cd .. && bash post-provision-setup.sh \"kcd-texas-spare-\$i\" \"${REGION}\""
echo "  done"
echo ""
echo "REMEMBER: Run batch-teardown.sh + manual teardown of presenter + spares IMMEDIATELY after the workshop."
echo "============================================="
