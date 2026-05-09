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
run_cmd "${ROOT_CMD[@]}" rm -rf "$OUTPUT_DIR"
run_cmd "${ROOT_CMD[@]}" debootstrap --arch="$ARCH" --variant=minbase "$RELEASE" "$OUTPUT_DIR" "$MIRROR"
run_cmd "${ROOT_CMD[@]}" cp "$PACKAGE_LIST" "$OUTPUT_DIR/tmp/base-packages.txt"
run_cmd "${ROOT_CMD[@]}" chroot "$OUTPUT_DIR" apt-get update
run_cmd "${ROOT_CMD[@]}" chroot "$OUTPUT_DIR" xargs -a /tmp/base-packages.txt apt-get install -y
run_cmd "${ROOT_CMD[@]}" chroot "$OUTPUT_DIR" rm -f /tmp/base-packages.txt

echo "Debian foundation created at: $OUTPUT_DIR"
