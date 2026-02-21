# This stage is responsible for holding onto
# your config without copying it directly into
# the final image
FROM scratch AS stage-files
COPY ./files /files

# Bins to install
# These are basic tools that are added to all images.
# Generally used for the build process. We use a multi
# stage process so that adding the bins into the image
# can be added to the ostree commits.
FROM scratch AS stage-bins
COPY --from=ghcr.io/sigstore/cosign/cosign:v3.0.2 \
  /ko-app/cosign /bins/cosign
COPY --from=ghcr.io/blue-build/cli:latest-installer \
  /out/bluebuild /bins/bluebuild
# Keys for pre-verified images
# Used to copy the keys into the final image
# and perform an ostree commit.
#
# Currently only holds the current image's
# public key.
FROM scratch AS stage-keys
COPY cosign.pub /keys/budgie-gaming.pub


# Main image
FROM quay.io/fedora-ostree-desktops/budgie-atomic@sha256:4da74d3e26972444035043efd6b5098e3261a7e9f5cb0b5aa178b088c27ee497 AS budgie-gaming
ARG TARGETARCH
ARG RECIPE=recipes/recipe.yml
ARG IMAGE_REGISTRY=localhost
ARG BB_BUILD_FEATURES=""
ARG CONFIG_DIRECTORY="/tmp/files"
ARG MODULE_DIRECTORY="/tmp/modules"
ARG IMAGE_NAME="budgie-gaming"
ARG BASE_IMAGE="quay.io/fedora-ostree-desktops/budgie-atomic"
ARG FORCE_COLOR=1
ARG CLICOLOR_FORCE=1
ARG RUST_LOG_STYLE=always
# Key RUN
RUN --mount=type=bind,from=stage-keys,src=/keys,dst=/tmp/keys \
  mkdir -p /etc/pki/containers/ \
  && cp /tmp/keys/* /etc/pki/containers/
# Bin RUN
RUN --mount=type=bind,from=stage-bins,src=/bins,dst=/tmp/bins \
  mkdir -p /usr/bin/ \
  && cp /tmp/bins/* /usr/bin/
RUN --mount=type=bind,from=ghcr.io/blue-build/nushell-image:default,src=/nu,dst=/tmp/nu \
  mkdir -p /usr/libexec/bluebuild/nu \
  && cp -r /tmp/nu/* /usr/libexec/bluebuild/nu/
RUN \
--mount=type=bind,src=.bluebuild-scripts_,dst=/scripts/,Z \
  /scripts/pre_build.sh

# Module RUNs
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/script:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_,dst=/tmp/scripts/,Z \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-budgie-gaming-43,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-budgie-gaming-43,sharing=locked \
/tmp/scripts/run_module.sh 'script' '{"type":"script","scripts":["setup-repos.sh"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/dnf:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_,dst=/tmp/scripts/,Z \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-budgie-gaming-43,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-budgie-gaming-43,sharing=locked \

# =====================================================================
# NVIDIA: Common akmods (v4l2loopback, signing keys)
# =====================================================================
# Copy pre-built common akmods RPMs from ublue-os registry
# TAG = main-43 (main kernel flavor, Fedora 43)
COPY --from=ghcr.io/ublue-os/akmods:main-43 / /tmp/akmods-common
RUN find /tmp/akmods-common && \
    dnf5 install -y /tmp/akmods-common/rpms/ublue-os/ublue-os-akmods*.rpm && \
    dnf5 install -y /tmp/akmods-common/rpms/kmods/kmod-v4l2loopback*.rpm && \
    rm -rf /tmp/akmods-common

# =====================================================================
# NVIDIA: nvidia-open kernel module + addons
# =====================================================================
# Copy pre-built nvidia-open driver RPMs from ublue-os registry
COPY --from=ghcr.io/ublue-os/akmods-nvidia-open:main-43 / /tmp/akmods-nvidia
RUN find /tmp/akmods-nvidia && \
    dnf5 install -y /tmp/akmods-nvidia/rpms/ublue-os/ublue-os-nvidia*.rpm && \
    dnf5 install -y /tmp/akmods-nvidia/rpms/kmods/kmod-nvidia*.rpm && \
    ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so && \
    rm -rf /tmp/akmods-nvidia

# =====================================================================
# NVIDIA: Kernel args (blacklist nouveau, enable NVIDIA DRM)
# =====================================================================
RUN mkdir -p /usr/lib/bootc/kargs.d && \
    echo '["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1", "nvidia-drm.fbdev=1"]' > /usr/lib/bootc/kargs.d/00-nvidia.toml || \
    true

/tmp/scripts/run_module.sh 'dnf' '{"type":"dnf","install":{"allow-erasing":true,"packages":["ffmpeg","gstreamer1-plugins-bad-free","gstreamer1-plugins-bad-freeworld","gstreamer1-plugins-ugly","gstreamer1-vaapi","libva-utils","mesa-va-drivers-freeworld","mesa-vdpau-drivers-freeworld","vulkan-loader","vulkan-tools","mesa-vulkan-drivers","mesa-dri-drivers","mesa-libGL","mesa-libEGL","mangohud","vkBasalt","gamemode","gamescope","joystick-support","steam-devices","tailscale","distrobox","toolbox","podman","ptyxis","topgrade","just","input-remapper","libcec","solaar","rom-properties-gtk3","webapp-manager","rocm-opencl","radeontop","google-noto-sans-fonts","google-noto-emoji-color-fonts","liberation-fonts","fira-code-fonts"]}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/files:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_,dst=/tmp/scripts/,Z \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-budgie-gaming-43,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-budgie-gaming-43,sharing=locked \
/tmp/scripts/run_module.sh 'files' '{"type":"files","files":[{"source":"system","destination":"/"}]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/default-flatpaks:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_,dst=/tmp/scripts/,Z \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-budgie-gaming-43,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-budgie-gaming-43,sharing=locked \
/tmp/scripts/run_module.sh 'default-flatpaks' '{"type":"default-flatpaks","configurations":[{"notify":true,"scope":"system","repo":{"url":"https://dl.flathub.org/repo/flathub.flatpakrepo","name":"flathub","title":"Flathub"},"install":["org.mozilla.firefox","com.github.tchx84.Flatseal","io.github.flattool.Warehouse","io.github.kolunmi.Bazaar","com.valvesoftware.Steam","net.lutris.Lutris","net.davidotek.pupgui2","org.videolan.VLC","com.obsproject.Studio","com.discordapp.Discord","org.gnome.FileRoller","org.gnome.Calculator"],"remove":["org.fedoraproject.MediaWriter"]}]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/systemd:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_,dst=/tmp/scripts/,Z \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-budgie-gaming-43,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-budgie-gaming-43,sharing=locked \
/tmp/scripts/run_module.sh 'systemd' '{"type":"systemd","system":{"enabled":["tailscaled.service","input-remapper.service","fstrim.timer","podman-auto-update.timer"],"disabled":[]}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/justfiles:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_,dst=/tmp/scripts/,Z \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-budgie-gaming-43,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-budgie-gaming-43,sharing=locked \
/tmp/scripts/run_module.sh 'justfiles' '{"type":"justfiles","include":["gaming.just"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/script:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_,dst=/tmp/scripts/,Z \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-budgie-gaming-43,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-budgie-gaming-43,sharing=locked \
/tmp/scripts/run_module.sh 'script' '{"type":"script","scripts":["post-install.sh"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/signing:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,src=.bluebuild-scripts_,dst=/tmp/scripts/,Z \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-budgie-gaming-43,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-budgie-gaming-43,sharing=locked \
/tmp/scripts/run_module.sh 'signing' '{"type":"signing"}'

RUN \
--mount=type=bind,src=.bluebuild-scripts_,dst=/scripts/,Z \
  /scripts/post_build.sh

# Labels are added last since they cause cache misses with buildah
LABEL io.artifacthub.package.readme-url="https://raw.githubusercontent.com/blue-build/cli/main/README.md"
LABEL org.blue-build.build-id="e8928987-2142-411f-b4ff-16a6e0bc439e"
LABEL org.opencontainers.image.base.digest="sha256:4da74d3e26972444035043efd6b5098e3261a7e9f5cb0b5aa178b088c27ee497"
LABEL org.opencontainers.image.base.name="quay.io/fedora-ostree-desktops/budgie-atomic:43"
LABEL org.opencontainers.image.created="2026-02-16T21:19:46.250878414+00:00"
LABEL org.opencontainers.image.description="A gaming-optimized Fedora Budgie Atomic desktop image"
LABEL org.opencontainers.image.source=""
LABEL org.opencontainers.image.title="budgie-gaming"
