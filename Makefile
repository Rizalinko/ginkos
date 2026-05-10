# GinkOS Build System
# Usage: make <target>

SHELL       := /bin/bash
VERSION     := 1.0
CODENAME    := maidenhair
ARCH        := amd64
OUTPUT_DIR  := output
ROOTFS      := rootfs

.PHONY: all bootstrap packages repo install iso clean help

all: bootstrap packages repo install
	@echo "GinkOS $(VERSION) build complete."

bootstrap: ## Bootstrap the Debian base system
	@echo "Bootstrapping GinkOS base..."
	@sudo ./build.sh bootstrap

packages: ## Build all .deb packages
	@echo "Building packages..."
	@./build.sh packages

repo: packages ## Publish packages to aptly repo
	@echo "Publishing repo..."
	@./build.sh repo

install: repo ## Install GinkOS packages into rootfs
	@echo "Installing packages into rootfs..."
	@sudo ./build.sh install

iso: install ## Build bootable ISO
	@echo "Building ISO..."
	@sudo ./iso/build-iso.sh

clean: ## Remove build artifacts
	@echo "Cleaning build artifacts..."
	@rm -rf $(OUTPUT_DIR)
	@rm -rf $(ROOTFS)
	@echo "Clean complete."

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; \
		       {printf "  \033[38;2;200;169;81m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
