#!/bin/bash
# build.sh — GinkOS reproducible build pipeline
# Usage: sudo ./build.sh [bootstrap|packages|repo|iso|all]

set -euo pipefail

# ── Config ────────────────────────────────────────────────────
GINKOS_VERSION="1.0"
GINKOS_CODENAME="maidenhair"
GINKOS_ARCH="amd64"
DEBIAN_SUITE="bookworm"
DEBIAN_MIRROR="http://deb.debian.org/debian"
ROOTFS="${PWD}/rootfs"
PACKAGES_DIR="${PWD}/packages"
REPO_DIR="${PWD}/repo"
ISO_DIR="${PWD}/iso"
OUTPUT_DIR="${PWD}/output"

# ── Logging ───────────────────────────────────────────────────
log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "[$(date +%H:%M:%S)] OK: $*"; }
fail() { echo "[$(date +%H:%M:%S)] FAIL: $*" >&2; exit 1; }

# ── Preflight checks ──────────────────────────────────────────
check_deps() {
    log "Checking build dependencies..."
    local deps=(debootstrap dpkg-deb aptly gpg xorriso \
                mksquashfs python3 git)
    for dep in "${deps[@]}"; do
        command -v "$dep" &>/dev/null \
            || fail "Missing dependency: $dep"
    done
    ok "All build dependencies present"
}

check_root() {
    [ "$EUID" -eq 0 ] || fail "bootstrap and iso targets require root"
}

# ── Bootstrap ─────────────────────────────────────────────────
bootstrap() {
    check_root
    log "Bootstrapping GinkOS base system..."

    if [ -d "$ROOTFS" ]; then
        log "Existing rootfs found at $ROOTFS"
        read -p "Remove and rebuild? [y/N] " confirm
        [[ "$confirm" == "y" ]] || { log "Skipping bootstrap."; return; }
        rm -rf "$ROOTFS"
    fi

    debootstrap \
        --arch="$GINKOS_ARCH" \
        --variant=minbase \
        "$DEBIAN_SUITE" \
        "$ROOTFS" \
        "$DEBIAN_MIRROR"

    ok "Base system bootstrapped at $ROOTFS"

    log "Configuring base system..."
    systemd-nspawn -D "$ROOTFS" bash -c "
        set -e
        echo ginkos > /etc/hostname
        ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime
        apt-get install -y locales
        sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
        locale-gen

        cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main
deb http://deb.debian.org/debian bookworm-updates main
SOURCES

        apt-get update
        apt-get install -y --no-install-recommends \
            systemd systemd-sysv dbus \
            linux-image-amd64 \
            openssh-server network-manager \
            sudo curl wget vim git \
            xorg xinit i3 i3status i3lock \
            alacritty rofi feh picom \
            firefox-esr \
            pulseaudio pavucontrol thunar \
            fonts-noto fonts-noto-color-emoji \
            python3 python3-rich

        useradd -m -s /bin/bash -G sudo,audio,video,netdev gink
        echo 'gink:ginkos' | chpasswd
        echo 'gink ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/gink
        chmod 440 /etc/sudoers.d/gink
    "
    ok "Base system configured"
}

# ── Build packages ────────────────────────────────────────────
build_packages() {
    log "Building .deb packages..."
    mkdir -p "$OUTPUT_DIR"

    for pkg_dir in "$PACKAGES_DIR"/*/; do
        pkg_name=$(basename "$pkg_dir")
        log "Building $pkg_name..."
        dpkg-deb --build --root-owner-group \
            "$pkg_dir" \
            "$OUTPUT_DIR/${pkg_name}.deb"
        ok "$pkg_name.deb built"
    done
}

# ── Publish repo ──────────────────────────────────────────────
publish_repo() {
    log "Publishing aptly repository..."

    aptly repo add ginkos "$OUTPUT_DIR"/*.deb

    aptly publish update \
        "$GINKOS_CODENAME" \
        filesystem:"${REPO_DIR}/public":ginkos \
    || aptly publish repo \
        -architectures="$GINKOS_ARCH" \
        -distribution="$GINKOS_CODENAME" \
        ginkos \
        filesystem:"${REPO_DIR}/public":ginkos

    ok "Repository published"
}

# ── Install packages into rootfs ──────────────────────────────
install_packages() {
    check_root
    log "Installing GinkOS packages into rootfs..."

    # Mount the local repo into the rootfs
    mkdir -p "$ROOTFS/tmp/ginkos-repo"
    mount --bind "$REPO_DIR/public" "$ROOTFS/tmp/ginkos-repo"

    systemd-nspawn -D "$ROOTFS" bash -c "
        echo 'deb [trusted=yes] file:///tmp/ginkos-repo maidenhair main' \
            > /etc/apt/sources.list.d/ginkos.list
        apt-get update
        apt-get install -y ginkos-defaults ginkos-sysinfo
        sudo gink-freeze
    "

    umount "$ROOTFS/tmp/ginkos-repo"
    ok "GinkOS packages installed into rootfs"
}

# ── Entry point ───────────────────────────────────────────────
TARGET="${1:-all}"
check_deps

case "$TARGET" in
    bootstrap)  bootstrap ;;
    packages)   build_packages ;;
    repo)       publish_repo ;;
    install)    install_packages ;;
    all)
        bootstrap
        build_packages
        publish_repo
        install_packages
        ;;
    *) fail "Unknown target: $TARGET. Use: bootstrap|packages|repo|install|all" ;;
esac

log "GinkOS build complete. Target: $TARGET"
