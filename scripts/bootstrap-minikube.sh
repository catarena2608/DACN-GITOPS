#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-dacn-lab}"
CPUS="${CPUS:-8}"
MEMORY="${MEMORY:-14336}"
DISK_SIZE="${DISK_SIZE:-80g}"
GITHUB_OWNER="${GITHUB_OWNER:-}"
GITOPS_REPOSITORY="${GITOPS_REPOSITORY:-dacn-gitops}"
BRANCH="${BRANCH:-main}"
FLUX_PATH="${FLUX_PATH:-clusters/lab}"
SKIP_FLUX_BOOTSTRAP="${SKIP_FLUX_BOOTSTRAP:-false}"

usage() {
  cat <<'EOF'
Usage:
  GITHUB_OWNER=<github-user-or-org> scripts/bootstrap-minikube.sh

Optional environment variables:
  PROFILE=dacn-lab
  CPUS=8
  MEMORY=14336
  DISK_SIZE=80g
  GITOPS_REPOSITORY=dacn-gitops
  BRANCH=main
  FLUX_PATH=clusters/lab
  SKIP_FLUX_BOOTSTRAP=true
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' was not found in PATH." >&2
    exit 1
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_command minikube
require_command kubectl

if [[ "$SKIP_FLUX_BOOTSTRAP" != "true" ]]; then
  require_command flux
fi

echo "Starting Minikube profile '$PROFILE'..."
minikube start \
  --profile "$PROFILE" \
  --driver docker \
  --cpus "$CPUS" \
  --memory "$MEMORY" \
  --disk-size "$DISK_SIZE"

for addon in metrics-server ingress storage-provisioner default-storageclass; do
  echo "Enabling Minikube addon '$addon'..."
  minikube addons enable "$addon" -p "$PROFILE"
done

echo "Using kubectl context '$PROFILE'..."
kubectl config use-context "$PROFILE"

echo "Cluster nodes:"
kubectl get nodes

if [[ "$SKIP_FLUX_BOOTSTRAP" == "true" ]]; then
  echo "Skipping Flux bootstrap."
  exit 0
fi

if [[ -z "$GITHUB_OWNER" ]]; then
  echo "GITHUB_OWNER is required unless SKIP_FLUX_BOOTSTRAP=true." >&2
  usage >&2
  exit 1
fi

echo "Bootstrapping FluxCD from $GITHUB_OWNER/$GITOPS_REPOSITORY path '$FLUX_PATH'..."
flux bootstrap github \
  --owner "$GITHUB_OWNER" \
  --repository "$GITOPS_REPOSITORY" \
  --branch "$BRANCH" \
  --path "$FLUX_PATH" \
  --personal

echo "Flux bootstrap requested. Check reconciliation with:"
echo "  flux get kustomizations -A"
echo "  flux get helmreleases -A"
