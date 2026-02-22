# gaming.just — Custom ujust recipes for the Budgie Gaming NVIDIA image
#
# Usage: ujust <recipe-name>

# Install Proton-GE (latest) via ProtonUp-Qt
install-protonge:
    #!/usr/bin/env bash
    echo "Launching ProtonUp-Qt to install Proton-GE..."
    flatpak run net.davidotek.pupgui2

# Configure MangoHud with nice defaults
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

# GameMode usage info
gamemode-info:
    #!/usr/bin/env bash
    echo "GameMode is installed and ready."
    echo ""
    echo "To use with Steam:"
    echo "  Set launch options to: gamemoderun %command%"
    echo ""
    echo "To combine with MangoHud:"
    echo "  gamemoderun mangohud %command%"

# Show system gaming info (NVIDIA variant)
gaming-info:
    #!/usr/bin/env bash
    echo "=== GPU Info ==="
    lspci | grep -i vga
    echo ""
    echo "=== NVIDIA Driver ==="
    nvidia-smi 2>/dev/null | head -10 || echo "nvidia-smi not available"
    echo ""
    echo "=== Vulkan ==="
    vulkaninfo --summary 2>/dev/null | head -20 || echo "vulkaninfo not available"
    echo ""
    echo "=== Kernel ==="
    uname -r

# NVIDIA settings
nvidia-settings:
    #!/usr/bin/env bash
    nvidia-settings
