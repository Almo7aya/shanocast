FROM fedora:42 AS builder

# Install build dependencies.  The *-static packages allow the final
# cast_receiver link step to consume archive libraries instead of ELF shared
# objects where Fedora provides them.
RUN dnf -y update && dnf -y install \
    gcc-c++ \
    glibc-static \
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
    SDL2-static \
    zlib-static \
    bzip2-static \
    xz-static \
    which \
    make \
    cmake \
    curl \
    patch \
    findutils \
    binutils && \
    dnf clean all

# Force GN/pkg-config dependency discovery to return static linker flags.
RUN printf '#!/bin/sh\nexec /usr/bin/pkg-config --static "$@"\n' > /usr/local/bin/pkg-config && \
    chmod +x /usr/local/bin/pkg-config

# Create build directory
WORKDIR /build

# Clone and patch openscreen
RUN git clone https://chromium.googlesource.com/openscreen.git && \
    cd openscreen && \
    git checkout 934f2462ad01c407a596641dbc611df49e2017b4 && \
    git submodule update --init --recursive

# Copy patch file
COPY shanocast.patch /build/

# Apply patch
RUN cd openscreen && \
    patch -p1 < /build/shanocast.patch

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

# Build binary.  The GN link flags ask the linker to prefer static archives,
# statically include the GCC/C++ runtimes, and fail if unresolved shared-library
# dependencies would be emitted.  If a dependency is only available as a shared
# object in the base image, the build fails here instead of uploading a binary
# with surprise runtime dependencies.
ARG EXTRA_GN_ARGS=""
RUN cd openscreen && \
    gn gen out/Default --args="is_debug=false use_custom_libcxx=false have_ffmpeg=true have_libsdl2=true cast_allow_developer_certificate=true is_clang=false extra_ldflags=[\"-static\",\"-static-libstdc++\",\"-static-libgcc\",\"-Wl,--as-needed\"] ${EXTRA_GN_ARGS}" && \
    find out/Default -name "*.ninja" -exec sed -i 's/-Werror/-Wno-error/g' {} + && \
    find out/Default -name "*.ninja" -exec sed -i 's/-Wno-unknown-warning-option//g' {} + && \
    sed -i 's/${cflags}/& -include stdint.h -D_GNU_SOURCE -Wno-old-style-definition -Wno-deprecated-non-prototype/g' out/Default/toolchain.ninja && \
    sed -i 's/$cflags/& -include stdint.h -D_GNU_SOURCE -Wno-old-style-definition -Wno-deprecated-non-prototype/g' out/Default/toolchain.ninja && \
    sed -i 's/-I..\/.."/-I..\/.."/g' out/Default/toolchain.ninja && \
    sed -i 's/-I..\/.."/"-I..\/.." "-I\/usr\/local\/include"/' out/Default/toolchain.ninja && \
    ninja -C out/Default cast_receiver && \
    cp out/Default/cast_receiver /build/shanocast && \
    file /build/shanocast && \
    ! readelf -d /build/shanocast | grep -q 'NEEDED'

FROM scratch AS artifact
COPY --from=builder /build/shanocast /shanocast

# Create a smaller runtime image.  The binary is statically linked, so this
# image intentionally carries no FFmpeg/SDL runtime packages.
FROM fedora:42

WORKDIR /app
COPY --from=builder /build/shanocast /app/
ENTRYPOINT ["/app/shanocast"]
