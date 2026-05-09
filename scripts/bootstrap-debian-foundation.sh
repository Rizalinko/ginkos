#!/usr/bin/env bash
set -euo pipefail

RELEASE="bookworm"
ARCH="amd64"
MIRROR="http://deb.debian.org/debian"
OUTPUT_DIR="$(pwd)/build/rootfs"
PACKAGE_LIST="$(pwd)/config/base-packages.txt"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      RELEASE="$2"
      shift 2
      ;;
    --arch)
      ARCH="$2"
      shift 2
      ;;
    --mirror)
      MIRROR="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

if [[ ! -f "$PACKAGE_LIST" ]]; then
  echo "Package list not found: $PACKAGE_LIST" >&2
  exit 1
fi

SAFE_OUTPUT_DIR="$(readlink -m "$OUTPUT_DIR")"
case "$SAFE_OUTPUT_DIR" in
  ""|"/"|"/home"|"/root"|"/tmp")
    echo "Refusing unsafe output directory: $SAFE_OUTPUT_DIR" >&2
    exit 1
    ;;
esac
OUTPUT_DIR="$SAFE_OUTPUT_DIR"

ROOT_CMD=()
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if [[ "$DRY_RUN" == false ]]; then
    require_cmd sudo
  fi
  ROOT_CMD=(sudo)
fi

if [[ "$DRY_RUN" == false ]]; then
  require_cmd debootstrap
fi

run_cmd mkdir -p "$(dirname "$OUTPUT_DIR")"
if [[ -z "$OUTPUT_DIR" || "$OUTPUT_DIR" != /* ]]; then
  echo "Refusing invalid output directory: $OUTPUT_DIR" >&2
  exit 1
fi
run_cmd "${ROOT_CMD[@]}" rm -rf "$OUTPUT_DIR"
if ! run_cmd "${ROOT_CMD[@]}" debootstrap --arch="$ARCH" --variant=minbase "$RELEASE" "$OUTPUT_DIR" "$MIRROR"; then
  echo "debootstrap failed. Verify release, mirror, and network connectivity." >&2
  exit 1
fi
run_cmd "${ROOT_CMD[@]}" chroot "$OUTPUT_DIR" apt-get update
while IFS= read -r package; do
  [[ -z "$package" || "$package" == \#* ]] && continue
  if ! run_cmd "${ROOT_CMD[@]}" chroot "$OUTPUT_DIR" apt-get install -y "$package"; then
    echo "Failed to install package: $package" >&2
    exit 1
  fi
done < "$PACKAGE_LIST"

echo "Debian foundation created at: $OUTPUT_DIR"
