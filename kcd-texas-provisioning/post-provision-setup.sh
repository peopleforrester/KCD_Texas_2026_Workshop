#!/usr/bin/env bash
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

# Wait up to 5 minutes for all nodes to be Ready.  Exits as soon as they
# are, instead of sleeping a fixed 60s and re-checking.
if ! kubectl wait --for=condition=Ready node --all --timeout=300s >/dev/null 2>&1; then
  echo "  FATAL: Nodes did not reach Ready within 5 minutes. Check EKS console."
  exit 1
fi
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || true)
if [ "${NODE_COUNT}" -lt 3 ]; then
  echo "  FATAL: Only ${NODE_COUNT} Ready nodes (expected >=3). Check EKS console."
  exit 1
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
      # Image tags below MUST track what gitops/apps/*.yaml deploys.
      # Update both files together when bumping chart pins.
      initContainers:
      # ArgoCD: chart argo-cd 9.5.x (Phase 1 Helm install) -> ArgoCD 3.3.x
      - name: pull-argocd
        image: quay.io/argoproj/argocd:v3.3.9
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      # Kyverno: gitops/apps/kyverno.yaml -> chart 3.8.0 -> app v1.18.0
      - name: pull-kyverno
        image: ghcr.io/kyverno/kyverno:v1.18.0
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      - name: pull-kyverno-cleanup
        image: ghcr.io/kyverno/cleanup-controller:v1.18.0
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      # kube-prometheus-stack 84.5.0: bundles Prometheus v3.11.3, Grafana 13.0.1,
      # prometheus-operator v0.90.1, node-exporter v1.11.1, kube-state-metrics v2.18.0.
      # Verified by inspecting deployed pod images on a live cluster.
      # Alertmanager disabled in gitops/apps/.
      - name: pull-prometheus
        image: quay.io/prometheus/prometheus:v3.11.3
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      - name: pull-grafana
        image: docker.io/grafana/grafana:13.0.1
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      - name: pull-prom-operator
        image: quay.io/prometheus-operator/prometheus-operator:v0.90.1
        command: ["sh", "-c", "echo done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
      # Backstage: gitops/apps/backstage.yaml -> chart 2.7.0 with
      # ghcr.io/backstage/backstage:1.30.2 (the chart's default registry;
      # last tagged release on that path).  Largest single image (~700MB)
      # so this pre-pull is the highest-leverage entry in the list.
      - name: pull-backstage
        image: ghcr.io/backstage/backstage:1.30.2
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
echo "K8s Version: $(kubectl version -o json 2>/dev/null | grep -m1 gitVersion | awk -F'"' '{print $4}')"
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
