# RizzOS

Basic Debian foundation scaffolding for RizzOS.

## Build the base root filesystem

This repository includes a bootstrap script that creates a minimal Debian root
filesystem using `debootstrap` and then installs a small default package set.

### Requirements

- Linux host
- `debootstrap`
- `sudo` (when not running as root)

### Usage

```bash
./scripts/bootstrap-debian-foundation.sh
```

Optional flags:

- `--release <name>` (default: `bookworm`)
- `--arch <arch>` (default: `amd64`)
- `--mirror <url>` (default: `http://deb.debian.org/debian`)
- `--output <path>` (default: `./build/rootfs`)
- `--dry-run` to print commands without executing them

> Safety: existing output directories are removed only when they already contain
> the `.rizzos-rootfs` marker file created by a prior successful run.
