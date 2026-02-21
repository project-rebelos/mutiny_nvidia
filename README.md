# Budgie Gaming Image

## What is this?

This is a **prototype** BlueBuild recipe that takes the official Fedora Budgie Atomic image and layers on gaming-focused packages and optimizations drawn from Bazzite's feature set.

**Target:** AMD GPU desktop users who want a gaming-ready Budgie desktop.

## Base Image

`quay.io/fedora-ostree-desktops/budgie-atomic:43` — the official Fedora Budgie Atomic image.

We chose this over `ublue-os/budgie-atomic-main` because Universal Blue deprecated their Budgie base image in September 2025. If it comes back, switching to it would give us free codec/driver support from the uBlue layer.

## What's Included

| Category | What You Get |
|---|---|
| **Multimedia** | Full codec support via RPM Fusion + Terra (H264, H265, VP9, AV1) |
| **GPU** | Latest Mesa from Terra, Vulkan drivers, AMD Southern/Sea Islands support |
| **Gaming Tools** | Steam, Lutris, MangoHud, vkBasalt, LatencyFleX, GameMode, Gamescope |
| **Controllers** | game-devices-udev rules for common gamepads |
| **Networking** | BBR TCP congestion control, Tailscale VPN |
| **Containers** | Distrobox + Podman preinstalled |
| **Terminal** | Ptyxis (container-aware terminal) |
| **Flatpaks** | Full Flathub enabled; Discord, OBS, ProtonUp-Qt, Heroic preinstalled |
| **Utilities** | input-remapper, webapp-manager, topgrade auto-updater |
| **AMD** | ROCm OpenCL runtime, radeontop monitoring |
| **Fonts** | Noto, Liberation, Fira Code |



## Next Steps (Iteration Plan)

Once this base builds and boots successfully, consider adding in order of impact:

1. **fsync kernel swap** — biggest gaming improvement (NTsync, HDR, scheduler support)
2. **sched-ext CPU schedulers** — LAVD/BORE for smoother gaming under load
3. **ZRAM tuning** — 4GB LZ4 for better memory management during gaming
4. **duperemove timer** — reduce Wine prefix disk usage
5. **xone akmod** — Xbox wireless controller support
6. **Kyber I/O scheduler** — prevent I/O starvation during game installs

## License

Apache-2.0 (same as Bazzite)
