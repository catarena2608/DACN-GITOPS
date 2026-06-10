#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
IMAGE_TAG="${2:-}"

usage() {
  cat <<'EOF'
Usage:
  scripts/set-image-tag.sh <staging|production> <image-tag>

Examples:
  scripts/set-image-tag.sh staging sha-abc1234
  scripts/set-image-tag.sh production sha-abc1234
EOF
}

if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
  usage >&2
  exit 2
fi

if [[ -z "$IMAGE_TAG" || "$IMAGE_TAG" =~ [[:space:]] ]]; then
  echo "Image tag is required and must not contain whitespace." >&2
  usage >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_FILE="$REPO_ROOT/apps/dacn/$ENVIRONMENT/helmrelease.yaml"

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "File not found: $TARGET_FILE" >&2
  exit 1
fi

export IMAGE_TAG
perl -0pi -e 's/(^[[:space:]]*global:[\s\S]*?^[[:space:]]*imageTag:[[:space:]]*)\S+/${1}$ENV{IMAGE_TAG}/m' "$TARGET_FILE"

if ! grep -q "imageTag: $IMAGE_TAG" "$TARGET_FILE"; then
  echo "Failed to update imageTag in $TARGET_FILE" >&2
  exit 1
fi

echo "Updated $ENVIRONMENT imageTag to $IMAGE_TAG"
echo "$TARGET_FILE"
