#!/usr/bin/env bash
# setup-repos.sh — Add COPR and third-party repositories
#
# Sets up package repos needed for gaming packages.
# NVIDIA repos are handled separately by install-nvidia.sh
# (via ublue-os-nvidia-addons RPM which ships negativo17 repo configs).
#
set -euo pipefail

echo ":: Setting up third-party repositories..."

FEDORA_VERSION="$(rpm -E %fedora)"

# ---- Terra repository (Fyra Labs) ----
# Provides: patched mesa, additional multimedia packages, topgrade, etc.
dnf5 -y install --nogpgcheck \
    --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_VERSION}" \
    terra-release terra-release-extras

# ---- RPM Fusion (Free + Nonfree) ----
# Provides: multimedia codecs, Steam, additional packages
# NOTE: We do NOT install NVIDIA drivers from RPM Fusion.
# The negativo17 repo (enabled by ublue-os-nvidia-addons) is used instead.
dnf5 -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

# ---- Exclude akmod-nvidia from RPM Fusion ----
# Prevent RPM Fusion's akmod-nvidia from ever being pulled in as a dependency.
# Our NVIDIA drivers come from negativo17 + ublue pre-built kmods.
dnf5 -y config-manager setopt "rpmfusion-nonfree".excludepkgs="akmod-nvidia,akmod-nvidia-open"
dnf5 -y config-manager setopt "rpmfusion-nonfree-updates".excludepkgs="akmod-nvidia,akmod-nvidia-open"

# ---- COPR: LatencyFleX ----
# Provides: latencyflex-vulkan-layer — reduces input latency in games
dnf5 -y copr enable kylegospo/LatencyFleX

# ---- COPR: webapp-manager ----
# Provides: webapp-manager — create web apps from websites
dnf5 -y copr enable kylegospo/webapp-manager

# ---- COPR: rom-properties ----
# Provides: rom-properties — file manager plugin to preview ROM metadata
dnf5 -y copr enable bazzite-org/rom-properties

# ---- Tailscale ----
dnf5 -y config-manager addrepo \
    --overwrite \
    --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
rpm --import https://pkgs.tailscale.com/stable/fedora/repo.gpg

dnf5 -y makecache || true

# ---- Set repo priorities ----
dnf5 -y config-manager setopt "*terra*".priority=3
dnf5 -y config-manager setopt "*rpmfusion*".priority=5

echo ":: Repository setup complete."
