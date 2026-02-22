#!/usr/bin/env bash
# install-nvidia.sh — Install NVIDIA drivers using ublue-os akmods method
#
# Based on: https://github.com/ublue-os/main/blob/main/build_files/nvidia-install.sh
#
# This script expects /tmp/akmods-nvidia to contain the contents of
# ghcr.io/ublue-os/akmods-nvidia-open:main-43 (COPY'd in by containerfile snippet).
#
set -euo pipefail

echo ":: Installing NVIDIA drivers (ublue-os akmods method)..."

AKMODNV_PATH="/tmp/akmods-nvidia/rpms"

# Show what we have to work with (aids debugging in CI)
echo ":: Contents of akmods-nvidia container:"
find /tmp/akmods-nvidia/ -type f | head -50

# -----------------------------------------------------------------------
# Step 1: Install ublue-os-nvidia-addons RPM
# This RPM provides:
#   - negativo17-fedora-nvidia.repo (disabled by default)
#   - nvidia-container-toolkit.repo (disabled by default)
#   - nvidia-kmod-common (satisfies kmod dependency)
#   - nvidia container SELinux policy
#   - akmods signing keys
# -----------------------------------------------------------------------
echo ":: Installing ublue-os-nvidia-addons..."
dnf5 install -y "${AKMODNV_PATH}"/ublue-os/ublue-os-nvidia*.rpm

# -----------------------------------------------------------------------
# Step 2: Temporarily disable RPM Fusion
# RPM Fusion's NVIDIA packaging has a hard dependency chain:
#   xorg-x11-drv-nvidia → nvidia-kmod → akmod-nvidia
# This is incompatible with pre-built kmods. We disable RPM Fusion
# during NVIDIA install and use negativo17 instead.
# -----------------------------------------------------------------------
echo ":: Temporarily disabling RPM Fusion for NVIDIA install..."
if ls /etc/yum.repos.d/rpmfusion*.repo 1>/dev/null 2>&1; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion*.repo
fi
if [ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo
fi

# -----------------------------------------------------------------------
# Step 3: Enable negativo17 NVIDIA repo
# The ublue-os-nvidia-addons RPM installed this repo file but left it
# disabled. We enable just the first instance.
# -----------------------------------------------------------------------
echo ":: Enabling negativo17 NVIDIA repo..."
if [ -f /etc/yum.repos.d/negativo17-fedora-nvidia.repo ]; then
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/negativo17-fedora-nvidia.repo
else
    echo "WARNING: negativo17-fedora-nvidia.repo not found!"
    echo "Contents of /etc/yum.repos.d/:"
    ls -la /etc/yum.repos.d/ | grep -i nvidia || true
    ls -la /etc/yum.repos.d/ | grep -i negativo || true
fi

# Also enable nvidia-container-toolkit if present
if [ -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]; then
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/nvidia-container-toolkit.repo
fi

# -----------------------------------------------------------------------
# Step 4: Install NVIDIA userspace drivers from negativo17
# These packages do NOT depend on akmod-nvidia.
# Package names are different from RPM Fusion (nvidia-driver vs xorg-x11-drv-nvidia).
# -----------------------------------------------------------------------
echo ":: Installing NVIDIA userspace drivers from negativo17..."
dnf5 install -y \
    nvidia-driver \
    nvidia-driver-cuda \
    nvidia-driver-libs.i686 \
    nvidia-settings \
    libva-nvidia-driver || {
        echo "ERROR: Failed to install NVIDIA userspace packages."
        echo "Trying without i686 libs..."
        dnf5 install -y \
            nvidia-driver \
            nvidia-driver-cuda \
            nvidia-settings \
            libva-nvidia-driver
    }

# -----------------------------------------------------------------------
# Step 5: Install the pre-built kmod from ublue akmods container
# This is the kernel module compiled for the exact kernel version
# in the base image. It should resolve cleanly now that
# nvidia-kmod-common is satisfied by ublue-os-nvidia-addons.
# -----------------------------------------------------------------------
echo ":: Installing pre-built NVIDIA kmod..."
dnf5 install -y "${AKMODNV_PATH}"/kmods/kmod-nvidia*.rpm

# -----------------------------------------------------------------------
# Step 6: Create compatibility symlink for NVIDIA ML library
# (Same as Bluefin's 03-install-kernel-akmods.sh line 91)
# -----------------------------------------------------------------------
echo ":: Creating libnvidia-ml.so symlink..."
ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so

# -----------------------------------------------------------------------
# Step 7: Disable negativo17 repos (no longer needed)
# -----------------------------------------------------------------------
echo ":: Disabling negativo17 repos post-install..."
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-nvidia.repo || true
if [ -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/nvidia-container-toolkit.repo
fi

# -----------------------------------------------------------------------
# Step 8: Re-enable RPM Fusion (needed for gaming packages later)
# -----------------------------------------------------------------------
echo ":: Re-enabling RPM Fusion..."
if ls /etc/yum.repos.d/rpmfusion*.repo 1>/dev/null 2>&1; then
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/rpmfusion*.repo
fi
if [ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]; then
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/fedora-cisco-openh264.repo
fi

# Re-apply akmod exclusions on RPM Fusion (belt and suspenders)
dnf5 -y config-manager setopt "rpmfusion-nonfree".excludepkgs="akmod-nvidia,akmod-nvidia-open" || true
dnf5 -y config-manager setopt "rpmfusion-nonfree-updates".excludepkgs="akmod-nvidia,akmod-nvidia-open" || true

# -----------------------------------------------------------------------
# Step 9: Set up bootc kernel arguments
# Blacklist nouveau, enable NVIDIA DRM modesetting and framebuffer device
# (Same kargs as Bluefin: 03-install-kernel-akmods.sh lines 92-94)
# -----------------------------------------------------------------------
echo ":: Setting up NVIDIA kernel arguments..."
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/00-nvidia.toml << 'KARGS'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1", "nvidia-drm.fbdev=1"]
KARGS

# -----------------------------------------------------------------------
# Step 10: Configure NVIDIA modprobe and dracut
# -----------------------------------------------------------------------
echo ":: Configuring NVIDIA modprobe..."
mkdir -p /usr/lib/modprobe.d
cat > /usr/lib/modprobe.d/nvidia.conf << 'EOF'
# Force NVIDIA modules to load, blacklist nouveau
blacklist nouveau
options nvidia-drm modeset=1 fbdev=1
EOF

# Dracut config to ensure nvidia modules are included in initramfs
mkdir -p /usr/lib/dracut/dracut.conf.d
cat > /usr/lib/dracut/dracut.conf.d/99-nvidia.conf << 'EOF'
force_drivers+=" i915 amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF

# -----------------------------------------------------------------------
# Step 11: Ensure nvidia kernel module type is set to open
# -----------------------------------------------------------------------
if [ -f /etc/nvidia/kernel.conf ]; then
    sed -i 's/^MODULE_VARIANT=.*/MODULE_VARIANT=nvidia-open/' /etc/nvidia/kernel.conf
fi

# -----------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------
echo ":: Cleaning up akmods-nvidia temp files..."
rm -rf /tmp/akmods-nvidia

echo ":: NVIDIA driver installation complete."
