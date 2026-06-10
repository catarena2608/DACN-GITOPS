#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-}"

usage() {
  cat <<'EOF'
Usage:
  scripts/promote-production.sh [image-tag]

If image-tag is omitted, the script copies the current staging imageTag.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -n "$IMAGE_TAG" && "$IMAGE_TAG" =~ [[:space:]] ]]; then
  echo "Image tag must not contain whitespace." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGING_FILE="$REPO_ROOT/apps/dacn/staging/helmrelease.yaml"
PRODUCTION_FILE="$REPO_ROOT/apps/dacn/production/helmrelease.yaml"

if [[ ! -f "$STAGING_FILE" || ! -f "$PRODUCTION_FILE" ]]; then
  echo "Expected staging and production HelmRelease files were not found." >&2
  exit 1
fi

if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG="$(awk '
    /^[[:space:]]*global:[[:space:]]*$/ { in_global=1; next }
    in_global && /^[[:space:]]*imageTag:[[:space:]]*/ { print $2; exit }
  ' "$STAGING_FILE")"
fi

if [[ -z "$IMAGE_TAG" ]]; then
  echo "Could not determine staging imageTag." >&2
  exit 1
fi

export IMAGE_TAG
perl -0pi -e 's/(^[[:space:]]*global:[\s\S]*?^[[:space:]]*imageTag:[[:space:]]*)\S+/${1}$ENV{IMAGE_TAG}/m' "$PRODUCTION_FILE"
perl -0pi -e 's/(^[[:space:]]*suspend:[[:space:]]*)true/${1}false/m' "$PRODUCTION_FILE"

if ! grep -q "imageTag: $IMAGE_TAG" "$PRODUCTION_FILE"; then
  echo "Failed to update production imageTag." >&2
  exit 1
fi

if ! grep -q "suspend: false" "$PRODUCTION_FILE"; then
  echo "Failed to unsuspend production HelmRelease." >&2
  exit 1
fi

echo "Promoted imageTag $IMAGE_TAG to production-like."
echo "Production HelmRelease is now unsuspended."
