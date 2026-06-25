FROM fedora:42 AS builder

# Install build dependencies.  Fedora does not ship every FFmpeg/SDL
# transitive dependency as a static archive, so the Docker build statically
# links the compiler runtimes and prefers static pkg-config metadata where
# available instead of forcing a fully-static link that cannot resolve on the
# GitHub-hosted runner.
RUN dnf -y update && dnf -y install \
    gcc-c++ \
    libstdc++-static \
    ninja-build \
    gn \
    git \
    python3 \
    python3-pip \
    pkg-config \
    ffmpeg-free-devel \
    libavcodec-free-devel \
    libavformat-free-devel \
    libavutil-free-devel \
    libswscale-free-devel \
    SDL2-devel \
    which \
    make \
    cmake \
    curl \
    patch \
    findutils \
    binutils \
    file && \
    dnf clean all

WORKDIR /build

RUN git clone https://chromium.googlesource.com/openscreen.git && \
    cd openscreen && \
    git checkout 934f2462ad01c407a596641dbc611df49e2017b4 && \
    git submodule update --init --recursive

COPY shanocast.patch /build/

RUN cd openscreen && \
    patch -p1 < /build/shanocast.patch

# Prefer static dependency metadata when pkg-config is used by GN rules.
RUN printf '#!/bin/sh\nexec /usr/bin/pkg-config --static "$@"\n' > /usr/local/bin/pkg-config && \
    chmod +x /usr/local/bin/pkg-config

# Fix compiler warnings and create FFmpeg include symlinks
RUN cd openscreen && \
    sed -i '127s/.*/using FileUniquePtr = std::unique_ptr<FILE, int(*)(FILE*)>;/' cast/receiver/channel/static_credentials.cc && \
    sed -i '226s/int domain;/int domain = 0;/' platform/impl/stream_socket_posix.cc && \
    sed -i '106s/int domain;/int domain = 0;/' platform/impl/udp_socket_posix.cc && \
    mkdir -p /usr/local/include && \
    ln -sf /usr/include/ffmpeg/libavcodec /usr/local/include/ && \
    ln -sf /usr/include/ffmpeg/libavformat /usr/local/include/ && \
    ln -sf /usr/include/ffmpeg/libavutil /usr/local/include/ && \
    ln -sf /usr/include/ffmpeg/libswscale /usr/local/include/

# Build binary.  We statically link libstdc++/libgcc and ask pkg-config for
# static flags where available.  A fully static Linux link is intentionally not
# forced because Fedora's FFmpeg/SDL stack does not provide all transitive static
# archives in the GitHub Actions environment.
ARG EXTRA_GN_ARGS=""
RUN cd openscreen && \
    gn gen out/Default --args="is_debug=false use_custom_libcxx=false have_ffmpeg=true have_libsdl2=true cast_allow_developer_certificate=true is_clang=false extra_ldflags=[\"-static-libstdc++\",\"-static-libgcc\",\"-Wl,--as-needed\"] ${EXTRA_GN_ARGS}" && \
    find out/Default -name "*.ninja" -exec sed -i 's/-Werror/-Wno-error/g' {} + && \
    find out/Default -name "*.ninja" -exec sed -i 's/-Wno-unknown-warning-option//g' {} + && \
    sed -i 's/\${cflags}/& -include stdint.h -D_GNU_SOURCE -Wno-old-style-definition -Wno-deprecated-non-prototype/g' out/Default/toolchain.ninja && \
    sed -i 's/\$cflags/& -include stdint.h -D_GNU_SOURCE -Wno-old-style-definition -Wno-deprecated-non-prototype/g' out/Default/toolchain.ninja && \
    sed -i 's/-I..\/.."/-I..\/.."/g' out/Default/toolchain.ninja && \
    sed -i 's/-I..\/.."/"-I..\/.." "-I\/usr\/local\/include"/' out/Default/toolchain.ninja && \
    ninja -C out/Default cast_receiver && \
    cp out/Default/cast_receiver /build/shanocast && \
    file /build/shanocast && \
    ldd /build/shanocast || true

FROM scratch AS artifact
COPY --from=builder /build/shanocast /shanocast

# Create a smaller runtime image
FROM fedora:42

# Install runtime dependencies still required by FFmpeg/SDL on Fedora.
RUN dnf -y update && dnf -y install \
    ffmpeg-free \
    SDL2 \
    mesa-dri-drivers \
    mesa-libGL \
    libva \
    libvdpau \
    pulseaudio-libs \
    alsa-lib \
    avahi \
    avahi-tools \
    nss-mdns \
    iproute && \
    dnf clean all

WORKDIR /app
COPY --from=builder /build/shanocast /app/
ENTRYPOINT ["/app/shanocast"]
