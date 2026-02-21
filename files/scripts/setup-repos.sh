#!/usr/bin/env bash
# setup-repos.sh — Add COPR and third-party repositories
#
# This script sets up the package repositories needed to install gaming
# packages that aren't in the default Fedora repos. Inspired by Bazzite's
# repo setup, but simplified for a desktop-only AMD build.
#
set -euo pipefail

echo ":: Setting up third-party repositories..."

FEDORA_VERSION="$(rpm -E %fedora)"

# ---- Terra repository (Fyra Labs) ----
# Provides: patched mesa, additional multimedia packages, topgrade, etc.
# Terra is a well-maintained third-party Fedora repo with curated packages.
dnf5 -y install --nogpgcheck \
    --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_VERSION}" \
    terra-release terra-release-extras terra-release-mesa

# ---- RPM Fusion (Free + Nonfree) ----
# Provides: multimedia codecs, Steam, additional drivers
# These are the standard third-party repos for Fedora.
dnf5 -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

# ---- COPR: kernel-fsync (sentry) ----
# Provides: the fsync-enabled kernel with gaming-relevant patches
# This is the kernel Bazzite builds its custom kernel from.
# NOTE: Using the fsync kernel rather than the full bazzite kernel,
# since the bazzite kernel COPR may have dependencies on bazzite-specific
# packages. The fsync kernel gives us the most impactful gaming patches
# (futex2/fsync, winesync/ntsync prep, HDR patches, etc.)

dnf5 -y copr enable bazzite-org/bazzite

# ---- COPR: LatencyFleX ----
# Provides: latencyflex-vulkan-layer — reduces input latency in games
# dnf5 -y copr enable kylegospo/LatencyFleX

# ---- COPR: hl2linux-selinux (Valve/Steam SELinux policies) ----
# Provides: SELinux policies that let Steam work properly on Fedora Atomic
# dnf5 -y copr enable kylegospo/hl2linux-selinux

# ---- COPR: webapp-manager ----
# Provides: webapp-manager — create web apps from websites
# dnf5 -y copr enable kylegospo/webapp-manager

# ---- COPR: rom-properties ----
# Provides: rom-properties — file manager plugin to preview ROM metadata
dnf5 -y copr enable bazzite-org/rom-properties -y

dnf5 -y makecache || true


# ---- Tailscale (optional but commonly wanted) ----
dnf5 -y config-manager addrepo \
    --overwrite \
    --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo

# Pre-import tailscale repo key for noninteractive builds
rpm --import https://pkgs.tailscale.com/stable/fedora/repo.gpg
dnf5 -y makecache --repo tailscale-stable || true

# ---- Set repo priorities ----
# Terra mesa builds should override Fedora's mesa for latest features.
# RPM Fusion should not override Terra or Fedora's mesa.
echo ":: Configuring repository priorities..."
dnf5 -y config-manager setopt "terra-mesa".enabled=true
dnf5 -y config-manager setopt "*terra*".priority=3
dnf5 -y config-manager setopt "*rpmfusion*".priority=5

# ---- NVIDIA Container Toolkit (optional — GPU passthrough to containers) ----
# NOTE: The ublue-os-nvidia-addons RPM may already provide this repo.
# Only add manually if you find it missing after a build.
# curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
#     tee /etc/yum.repos.d/nvidia-container-toolkit.repo



echo ":: Repository setup complete."
