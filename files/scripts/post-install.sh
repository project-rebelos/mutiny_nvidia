#!/usr/bin/env bash
# post-install.sh — Final system tweaks after all packages are installed
set -euo pipefail

echo ":: Running post-install tweaks..."

# ---- Enable full Flathub (replace Fedora's filtered version) ----
if flatpak remotes --system --columns=name | grep -Fxq fedora; then
  flatpak remote-delete --system fedora
fi

if flatpak remotes --system --columns=name | grep -Fxq fedora-testing; then
  flatpak remote-delete --system fedora-testing
fi

# ---- Clean up RPM caches to reduce image size ----
dnf5 clean all
rm -rf /var/cache/dnf5/*

# ---- Set os-release branding ----
if [ -f /usr/lib/os-release ]; then
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Budgie Gaming NVIDIA Desktop (Fedora 43)"/' /usr/lib/os-release
    sed -i 's/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="budgie-gaming-nvidia"/' /usr/lib/os-release
    if ! grep -q "IMAGE_NAME" /usr/lib/os-release; then
        echo 'IMAGE_NAME="budgie-gaming-nvidia"' >> /usr/lib/os-release
    fi
fi

echo ":: Post-install tweaks complete."
