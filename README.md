# Budgie Gaming NVIDIA

A gaming-optimized Fedora Budgie Atomic (Onyx) image with NVIDIA drivers.

## GPU Support

- **NVIDIA RTX 30-series and newer** (uses `nvidia-open` kernel module)
- Pre-built kernel modules from [ublue-os/akmods](https://github.com/ublue-os/akmods)
- Userspace drivers from the [negativo17](https://negativo17.org/) repository

## How NVIDIA Drivers Work

This image uses the same NVIDIA installation method as Universal Blue's Bluefin/Aurora/Bazzite:

1. Pre-built `kmod-nvidia` is copied from `ghcr.io/ublue-os/akmods-nvidia-open:main-43`
2. `ublue-os-nvidia-addons` RPM provides repo configs and signing keys
3. Userspace drivers (`nvidia-driver`, `nvidia-settings`, etc.) come from negativo17 (NOT RPM Fusion)
4. Kernel arguments are set via bootc to blacklist nouveau and enable modesetting

## Included Software

- Steam (Flatpak), MangoHud, vkBasalt, GameMode, Gamescope
- Tailscale, Distrobox, Podman
- Full multimedia codec support (FFmpeg, GStreamer)
- Controller support (Steam, Xbox, PlayStation, etc.)

## Installation

```bash
# Rebase from any Fedora Atomic desktop:
rpm-ostree rebase ostree-unverified-registry:ghcr.io/<your-username>/budgie-gaming-nvidia:latest
```

## Building

Builds automatically via GitHub Actions. To build locally:

```bash
bluebuild build recipes/recipe.yml
```
