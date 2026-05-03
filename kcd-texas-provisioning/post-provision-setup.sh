#!/bin/bash
# post-provision-setup.sh
# Run AFTER terraform apply completes.
# Configures kubectl, validates the cluster, installs workshop prerequisites,
# and creates the namespace structure needed for the 90-Minute IDP workshop.
#
# Usage: ./post-provision-setup.sh [cluster-name] [region]
# Example: ./post-provision-setup.sh kcd-texas-workshop us-east-2

set -euo pipefail

CLUSTER_NAME="${1:-kcd-texas-workshop}"
REGION="${2:-us-east-2}"

echo "============================================="
echo "KCD Texas Workshop - Post-Provision Setup"
echo "Cluster: ${CLUSTER_NAME}"
echo "Region:  ${REGION}"
echo "============================================="

# -----------------------------------------------
# 1. Configure kubectl
# -----------------------------------------------
echo ""
echo "[1/6] Configuring kubectl..."
aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}"
echo "  kubectl context set to ${CLUSTER_NAME}"

# -----------------------------------------------
# 2. Validate cluster is healthy
# -----------------------------------------------
echo ""
echo "[2/6] Validating cluster health..."

NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || true)
if [ "${NODE_COUNT}" -lt 3 ]; then
  echo "  ERROR: Expected at least 3 Ready nodes, found ${NODE_COUNT}"
  echo "  Waiting 60 seconds for nodes to come up..."
  sleep 60
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || true)
  if [ "${NODE_COUNT}" -lt 3 ]; then
    echo "  FATAL: Still only ${NODE_COUNT} Ready nodes. Check EKS console."
    exit 1
  fi
fi
echo "  ${NODE_COUNT} nodes Ready"

# Check system pods
PENDING_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l || true)
if [ "${PENDING_PODS}" -gt 0 ]; then
  echo "  WARNING: ${PENDING_PODS} pods not yet Running. Waiting 90 seconds..."
  sleep 90
fi
echo "  System pods healthy"

# -----------------------------------------------
# 3. Verify Helm is installed
# -----------------------------------------------
echo ""
echo "[3/6] Checking Helm..."
if ! command -v helm &> /dev/null; then
  echo "  Helm not found. Installing..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
HELM_VERSION=$(helm version --short 2>/dev/null)
echo "  Helm version: ${HELM_VERSION}"

# -----------------------------------------------
# 4. Create workshop namespace structure
# -----------------------------------------------
echo ""
echo "[4/6] Creating namespace structure..."

NAMESPACES=(
  "argocd"
  "kyverno"
  "monitoring"
  "backstage"
  "apps"
  "sample-app"
)

for NS in "${NAMESPACES[@]}"; do
  kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace "${NS}" workshop=kcd-texas-2026 --overwrite
done
echo "  ${#NAMESPACES[@]} namespaces created"

# -----------------------------------------------
# 5. Pre-pull critical images (reduces workshop wait time)
# -----------------------------------------------
echo ""
echo "[5/6] Pre-pulling container images..."
echo "  This runs as a DaemonSet so images are cached on every node."
echo "  It will take a few minutes. The workshop can start while this runs."

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-prepull
  namespace: default
  labels:
    purpose: workshop-prepull
spec:
  selector:
    matchLabels:
      purpose: workshop-prepull
  template:
    metadata:
      labels:
        purpose: workshop-prepull
    spec:
      initContainers:
      - name: pull-argocd
        image: quay.io/argoproj/argocd:v2.14.2
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      - name: pull-kyverno
        image: ghcr.io/kyverno/kyverno:v1.13.4
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      - name: pull-prometheus
        image: quay.io/prometheus/prometheus:v3.1.0
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      - name: pull-grafana
        image: grafana/grafana:11.4.0
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      containers:
      - name: pause
        image: registry.k8s.io/pause:3.10
        resources:
          requests:
            cpu: 1m
            memory: 4Mi
          limits:
            memory: 8Mi
      terminationGracePeriodSeconds: 0
      tolerations:
      - operator: Exists
EOF

echo "  Image pre-pull DaemonSet deployed"

# -----------------------------------------------
# 6. Cluster summary
# -----------------------------------------------
echo ""
echo "[6/6] Cluster summary"
echo "============================================="
echo "Cluster:     ${CLUSTER_NAME}"
echo "Region:      ${REGION}"
echo "K8s Version: $(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || kubectl version -o json 2>/dev/null | grep -m1 gitVersion | awk -F'"' '{print $4}')"
echo "Nodes:       ${NODE_COUNT}"
echo "Namespaces:  ${NAMESPACES[*]}"
echo ""
echo "Kubeconfig:  aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}"
echo ""
echo "NEXT STEPS:"
echo "  1. Clone the workshop repo:  git clone <REPO_URL>"
echo "  2. Install Claude Code if not already installed"
echo "  3. Verify:  kubectl get nodes"
echo "============================================="
echo ""
echo "To clean up the pre-pull DaemonSet after images are cached:"
echo "  kubectl delete daemonset image-prepull"
echo ""
echo "To destroy the cluster after the workshop:"
echo "  terraform destroy -auto-approve"
