#!/usr/bin/env bash
set -euo pipefail

KUSTOMIZE_PATH="${KUSTOMIZE_PATH:-clusters/lab}"
CHECK_CLUSTER="${CHECK_CLUSTER:-false}"

usage() {
  cat <<'EOF'
Usage:
  scripts/validate-gitops.sh
  CHECK_CLUSTER=true scripts/validate-gitops.sh

Optional environment variables:
  KUSTOMIZE_PATH=clusters/lab
  CHECK_CLUSTER=false
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FULL_PATH="$REPO_ROOT/$KUSTOMIZE_PATH"

require_command kubectl

echo "Rendering Kustomize path: $FULL_PATH"
kubectl kustomize "$FULL_PATH" >/dev/null
echo "Kustomize render OK."

if [[ "$CHECK_CLUSTER" != "true" ]]; then
  exit 0
fi

require_command flux

echo "Checking Flux installation..."
flux check

echo "Flux sources:"
flux get sources git -A
flux get sources helm -A

echo "Flux HelmReleases:"
flux get helmreleases -A

echo "Cluster pods:"
kubectl get pods -A
