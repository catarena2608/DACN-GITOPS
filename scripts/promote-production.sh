#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG=""
QUALITY_GATE_SUMMARY="${QUALITY_GATE_SUMMARY:-}"

usage() {
  cat <<'EOF'
Usage:
  scripts/promote-production.sh [--gate-summary <summary-file>] [image-tag]

If image-tag is omitted, the script copies the current staging imageTag.
If --gate-summary is omitted, the script uses the newest
../DACN/reports/production-gate/*/production-readiness-summary.md file.
The summary must be generated for the same image tag.

Environment:
  QUALITY_GATE_SUMMARY can be used instead of --gate-summary.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --gate-summary)
      if [[ -z "${2:-}" ]]; then
        echo "--gate-summary requires a file path." >&2
        exit 2
      fi
      QUALITY_GATE_SUMMARY="$2"
      shift 2
      ;;
    *)
      if [[ -n "$IMAGE_TAG" ]]; then
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 2
      fi
      IMAGE_TAG="$1"
      shift
      ;;
  esac
done

if [[ -n "$IMAGE_TAG" && "$IMAGE_TAG" =~ [[:space:]] ]]; then
  echo "Image tag must not contain whitespace." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGING_FILE="$REPO_ROOT/apps/dacn/staging/helmrelease.yaml"
PRODUCTION_FILE="$REPO_ROOT/apps/dacn/production/helmrelease.yaml"
DEFAULT_REPORTS_DIR="$REPO_ROOT/../DACN/reports/production-gate"

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

QUALITY_GATE_SUMMARY="${QUALITY_GATE_SUMMARY/#\~/$HOME}"

if [[ -z "$QUALITY_GATE_SUMMARY" ]]; then
  QUALITY_GATE_SUMMARY="$(find "$DEFAULT_REPORTS_DIR" -mindepth 2 -maxdepth 2 -name production-readiness-summary.md -print 2>/dev/null | sort | tail -n 1 || true)"
  if [[ -z "$QUALITY_GATE_SUMMARY" ]]; then
    echo "No production-readiness summary was found under $DEFAULT_REPORTS_DIR." >&2
    echo "Run the quality gate first, pass --gate-summary <file>, or set QUALITY_GATE_SUMMARY." >&2
    exit 2
  fi
fi

if [[ ! -f "$QUALITY_GATE_SUMMARY" ]]; then
  echo "Quality gate summary was not found: $QUALITY_GATE_SUMMARY" >&2
  exit 1
fi

echo "Using quality gate summary: $QUALITY_GATE_SUMMARY"

SUMMARY_TAG="$(awk -F': ' '/^- Expected image tag:/ { print $2; exit }' "$QUALITY_GATE_SUMMARY" | tr -d '\r')"

if [[ "$SUMMARY_TAG" != "$IMAGE_TAG" ]]; then
  echo "Quality gate tag does not match production promotion tag." >&2
  echo "  gate summary tag: ${SUMMARY_TAG:-not found}" >&2
  echo "  promote tag:      $IMAGE_TAG" >&2
  exit 1
fi

if grep -Eq '^\|[[:space:]]*FAIL[[:space:]]*\|' "$QUALITY_GATE_SUMMARY"; then
  echo "Quality gate summary contains failed gates. Promotion is blocked." >&2
  exit 1
fi

if ! grep -Eq '^PASS\. The tested artifact is eligible for production promotion' "$QUALITY_GATE_SUMMARY"; then
  echo "Quality gate summary does not contain a PASS promotion decision." >&2
  exit 1
fi

if ! awk -v tag=":$IMAGE_TAG" '
  /^## Tested Images/ { in_images=1; next }
  /^## Decision/ { in_images=0 }
  in_images && /^\| dacn-/ {
    seen=1
    if (index($0, tag) == 0) bad=1
  }
  END { exit !(seen && !bad) }
' "$QUALITY_GATE_SUMMARY"; then
  echo "Quality gate tested images do not all use tag $IMAGE_TAG." >&2
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

echo "Quality gate passed for imageTag $IMAGE_TAG."
echo "Promoted imageTag $IMAGE_TAG to production-like."
echo "Production HelmRelease is now unsuspended."
