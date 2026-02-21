#!/usr/bin/env bash
set -euo pipefail
echo ":: Installing multimedia codecs (ffmpeg + freeworld replacements)..."
dnf5 -y install --allowerasing \
    ffmpeg \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly
echo ":: Codec installation complete."

# Remove tuned-ppd first (conflicts with power-profiles-daemon)
dnf5 -y remove tuned-ppd || true
dnf5 -y install power-profiles-daemon
