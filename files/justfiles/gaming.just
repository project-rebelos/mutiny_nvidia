# gaming.just — Custom ujust recipes for the Budgie Gaming image
#
# Usage: ujust <recipe-name>
# These provide convenient shortcuts for common gaming setup tasks.

# Install Proton-GE (latest) via ProtonUp-Qt
install-protonge:
    #!/usr/bin/env bash
    echo "Launching ProtonUp-Qt to install Proton-GE..."
    flatpak run net.davidotek.pupgui2

# Set up Waydroid (Android on Linux)
setup-waydroid:
    #!/usr/bin/env bash
    echo "Setting up Waydroid..."
    sudo waydroid init -s GAPPS
    echo "Waydroid initialized. Start with: waydroid session start"

# Install MangoHud config for nice defaults
configure-mangohud:
    #!/usr/bin/env bash
    mkdir -p ~/.config/MangoHud
    cat > ~/.config/MangoHud/MangoHud.conf << 'EOF'
    fps
    frametime
    cpu_temp
    gpu_temp
    ram
    vram
    position=top-left
    font_size=20
    background_alpha=0.3
    EOF
    echo "MangoHud configured. Press F12 in supported games to toggle."

# Enable GameMode for a specific game (shows instructions)
gamemode-info:
    #!/usr/bin/env bash
    echo "GameMode is installed and ready."
    echo ""
    echo "To use with Steam:"
    echo "  Set launch options to: gamemoderun %command%"
    echo ""
    echo "To use with Lutris:"
    echo "  Enable 'Feral GameMode' in Lutris game settings."
    echo ""
    echo "To combine with MangoHud:"
    echo "  gamemoderun mangohud %command%"

# Install OpenRazer for Razer peripherals
install-openrazer:
    #!/usr/bin/env bash
    echo "Installing OpenRazer..."
    sudo dnf5 -y install openrazer-meta
    echo "Install Polychromatic for GUI control:"
    flatpak install -y flathub org.polychromatic.polychromatic

# Show system GPU and driver info
gaming-info:
    #!/usr/bin/env bash
    echo "=== GPU Info ==="
    lspci | grep -iE 'vga|3d'
    echo ""
    echo "=== NVIDIA Driver ==="
    nvidia-smi 2>/dev/null || echo "nvidia-smi not available (driver not loaded?)"
    echo ""
    echo "=== NVIDIA Kernel Module ==="
    modinfo nvidia 2>/dev/null | grep -E '^(filename|version|license):' || echo "nvidia module not found"
    echo ""
    echo "=== Vulkan ==="
    vulkaninfo --summary 2>/dev/null | head -25 || echo "vulkaninfo not available"
    echo ""
    echo "=== VAAPI ==="
    vainfo 2>/dev/null | head -15 || echo "vainfo not available"
    echo ""
    echo "=== Kernel ==="
    uname -r

# Set NVIDIA kernel arguments (for users who rebased from a non-NVIDIA image)
nvidia-set-kargs:
    #!/usr/bin/env bash
    echo "Setting NVIDIA kernel arguments..."
    sudo rpm-ostree kargs \
        --append-if-missing=rd.driver.blacklist=nouveau \
        --append-if-missing=modprobe.blacklist=nouveau \
        --append-if-missing=nvidia-drm.modeset=1 \
        --append-if-missing=nvidia-drm.fbdev=1 \
        --delete-if-present=nomodeset
    echo "Done. Reboot to apply."

# Enable NVIDIA VAAPI in Firefox Flatpak (hardware video decode)
firefox-nvidia-vaapi:
    #!/usr/bin/env bash
    echo "Enabling NVIDIA VAAPI in Firefox Flatpak..."
    flatpak override --user --env=LIBVA_DRIVER_NAME=nvidia org.mozilla.firefox
    flatpak override --user --env=NVD_BACKEND=direct org.mozilla.firefox
    flatpak override --user --env=MOZ_DISABLE_RDD_SANDBOX=1 org.mozilla.firefox
    echo "Done. Restart Firefox to apply."

# Test CUDA support
test-cuda:
    #!/usr/bin/env bash
    if command -v nvidia-smi &>/dev/null; then
        echo "=== CUDA Version ==="
        nvidia-smi | grep "CUDA Version" || echo "CUDA version not reported"
        echo ""
        echo "=== GPU Processes ==="
        nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv,noheader 2>/dev/null || echo "No compute processes running"
    else
        echo "nvidia-smi not found. Is the NVIDIA driver loaded?"
        echo "Try: ujust nvidia-set-kargs"
    fi
