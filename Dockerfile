# SC1000 Development Environment - Multi-stage build support
# Note: PLATFORM specifies the HOST platform (where Docker runs), not the TARGET.
# The TARGET is ARM32 (ARMv7-A Cortex-A8) as configured in buildroot_config.
# Use linux/arm64 for Apple Silicon Macs, linux/amd64 for Intel Macs/x86_64.
ARG PLATFORM=linux/arm64
FROM --platform=${PLATFORM} ubuntu:20.04

# Environment variable configuration
# CFLAGS and CXXFLAGS to suppress format-overflow warnings in BlueZ dependencies (glib2, etc.)
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    FORCE_UNSAFE_CONFIGURE=1 \
    BUILDROOT_OUTPUT_DIR=/work/buildroot-output \
    CC_ARM=/work/buildroot-output/host/usr/bin/arm-linux-gcc \
    CFLAGS="-Wno-format-overflow" \
    CXXFLAGS="-Wno-format-overflow"

# Install required packages in bulk
# Install gcc-7 and g++-7 for compatibility with buildroot 2018.08.4 and glib2
# Install dosfstools and mtools for genimage (sdcard.img generation)
# Install swig and python3-dev for U-Boot 2019.01+ pylibfdt support
RUN apt-get update && apt-get install -y \
    build-essential git wget cpio unzip rsync bc \
    python python3 python3-dev file libncurses5-dev libssl-dev \
    libelf-dev bison flex patch gawk cmake make \
    gcc-7 g++-7 \
    libasound2-dev pkg-config \
    dosfstools mtools \
    swig \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set gcc-7 and g++-7 as default compilers for buildroot compatibility
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 100 \
    && update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-7 100 \
    && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-7 100

WORKDIR /work

# Prepare buildroot (download only)
RUN wget -q https://buildroot.org/downloads/buildroot-2018.08.4.tar.gz \
    && tar -xzf buildroot-2018.08.4.tar.gz \
    && rm buildroot-2018.08.4.tar.gz

# Create directories for persistent buildroot output and download cache
RUN mkdir -p /work/buildroot-output /work/buildroot-2018.08.4/dl

# Create integrated script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
BUILDROOT_DIR="/work/buildroot-2018.08.4"\n\
SC1000_DIR="/work/SC1000"\n\
BUILDROOT_OUTPUT_DIR="/work/buildroot-output"\n\
\n\
show_usage() {\n\
    echo "SC1000 Build Tool (with persistent buildroot output)"\n\
    echo "Usage: $0 [COMMAND]"\n\
    echo "Commands:"\n\
    echo "  os       - Build Linux OS image (buildroot)"\n\
    echo "  toolchain - Build ARM cross-compiler only"\n\
    echo "  software - Build xwax software (ARM)"\n\
    echo "  native   - Build xwax native (x86/ARM64 for testing)"\n\
    echo "  updater  - Create updater package"\n\
    echo "  all      - Build everything (os + software + updater)"\n\
    echo "  clean    - Clean build artifacts (except persistent cache)"\n\
    echo "  clean-all - Clean everything including persistent cache"\n\
    echo "  shell    - Start interactive shell"\n\
    echo "  info     - Show build information"\n\
}\n\
\n\
show_info() {\n\
    echo "=== SC1000 Build Information ==="\n\
    echo "Buildroot directory: $BUILDROOT_DIR"\n\
    echo "Persistent output: $BUILDROOT_OUTPUT_DIR"\n\
    echo "Cross-compiler: $CC_ARM"\n\
    echo ""\n\
    if [ -f "$CC_ARM" ]; then\n\
        echo "Toolchain status: Available ($($CC_ARM --version | head -1))"\n\
    else\n\
        echo "Toolchain status: Not built yet"\n\
    fi\n\
    \n\
    if [ -d "$BUILDROOT_OUTPUT_DIR/images" ]; then\n\
        echo "OS images: Available"\n\
        ls -la "$BUILDROOT_OUTPUT_DIR/images/" | grep -E "\\.img|\\.tar|\\.dtb|zImage" || true\n\
    else\n\
        echo "OS images: Not built yet"\n\
    fi\n\
    \n\
    if [ -f "$SC1000_DIR/software/xwax" ]; then\n\
        echo "xwax software: Available"\n\
    else\n\
        echo "xwax software: Not built yet"\n\
    fi\n\
}\n\
\n\
build_os() {\n\
    echo "=== Building SC1000 OS ==="\n\
    cd "$BUILDROOT_DIR"\n\
    \n\
    # Ensure persistent output directory exists\n\
    mkdir -p "$BUILDROOT_OUTPUT_DIR"\n\
    \n\
    # For O= option, config file must be in output directory\n\
    cp "$SC1000_DIR/os/buildroot/buildroot_config" "$BUILDROOT_OUTPUT_DIR/.config"\n\
    \n\
    # Create overlay link in buildroot source directory\n\
    [ ! -e sc1000overlay ] && ln -sf "$SC1000_DIR/os/buildroot/sc1000overlay" sc1000overlay\n\
    \n\
    # Copy local.mk for package overrides\n\
    if [ -f "$SC1000_DIR/os/buildroot/local.mk" ]; then\n\
        cp "$SC1000_DIR/os/buildroot/local.mk" local.mk\n\
        echo "Copied local.mk for package overrides"\n\
    fi\n\
    # Copy patches/libglib2.mk to package/libglib2/ if it exists\n\
    if [ -f "$SC1000_DIR/os/buildroot/patches/libglib2.mk" ]; then\n\
        mkdir -p package/libglib2\n\
        if [ -f package/libglib2/libglib2.mk ]; then\n\
            echo "# Include libglib2 patches" >> package/libglib2/libglib2.mk\n\
            cat "$SC1000_DIR/os/buildroot/patches/libglib2.mk" >> package/libglib2/libglib2.mk\n\
        else\n\
            cp "$SC1000_DIR/os/buildroot/patches/libglib2.mk" package/libglib2/libglib2.mk\n\
        fi\n\
        echo "Included patches/libglib2.mk in package/libglib2/libglib2.mk"\n\
    fi\n\
    \n\
    # Verify config file exists in output directory\n\
    if [ ! -f "$BUILDROOT_OUTPUT_DIR/.config" ]; then\n\
        echo "Error: .config file not found in $BUILDROOT_OUTPUT_DIR"\n\
        exit 1\n\
    fi\n\
    \n\
    echo "Building buildroot (output will be persisted)..."\n\
    echo "This may take 1+ hours on first build, but will be faster on subsequent builds."\n\
    echo "Config file: $(ls -la $BUILDROOT_OUTPUT_DIR/.config)"\n\
    echo "Output directory: $BUILDROOT_OUTPUT_DIR"\n\
    \n\
    # Set CFLAGS to suppress format-overflow warnings in BlueZ dependencies\n\
    export CFLAGS="-Wno-format-overflow"\n\
    export CXXFLAGS="-Wno-format-overflow"\n\
    \n\
    # Use O= option to specify output directory explicitly\n\
    make O="$BUILDROOT_OUTPUT_DIR" -j$(nproc)\n\
    echo "OS build completed: $BUILDROOT_OUTPUT_DIR/images/"\n\
}\n\
\n\
build_software() {\n\
    echo "=== Building SC1000 Software ==="\n\
    if [ ! -f "$CC_ARM" ]; then\n\
        echo "Cross-compiler not found. Building toolchain..."\n\
        build_toolchain_only\n\
    fi\n\
    \n\
    cd "$SC1000_DIR/software"\n\
    make clean || true\n\
    echo "Using cross-compiler: $CC_ARM"\n\
    make CC="$CC_ARM"\n\
    echo "Software build completed: $SC1000_DIR/software/xwax"\n\
}\n\
\n\
build_toolchain_only() {\n\
    echo "=== Building ARM Toolchain Only ==="\n\
    cd "$BUILDROOT_DIR"\n\
    \n\
    # Ensure persistent output directory exists\n\
    mkdir -p "$BUILDROOT_OUTPUT_DIR"\n\
    \n\
    # For O= option, config file must be in output directory\n\
    cp "$SC1000_DIR/os/buildroot/buildroot_config" "$BUILDROOT_OUTPUT_DIR/.config"\n\
    \n\
    # Create overlay link in buildroot source directory\n\
    [ ! -e sc1000overlay ] && ln -sf "$SC1000_DIR/os/buildroot/sc1000overlay" sc1000overlay\n\
    \n\
    # Verify config file exists in output directory\n\
    if [ ! -f "$BUILDROOT_OUTPUT_DIR/.config" ]; then\n\
        echo "Error: .config file not found in $BUILDROOT_OUTPUT_DIR"\n\
        exit 1\n\
    fi\n\
    \n\
    echo "Building ARM cross-compiler (output will be persisted)..."\n\
    echo "This may take 20-30 minutes on first build, but will be instant on subsequent builds if cached."\n\
    echo "Config file: $(ls -la $BUILDROOT_OUTPUT_DIR/.config)"\n\
    echo "Output directory: $BUILDROOT_OUTPUT_DIR"\n\
    \n\
    # Use O= option to specify output directory explicitly\n\
    make O="$BUILDROOT_OUTPUT_DIR" toolchain -j$(nproc)\n\
    echo "Toolchain build completed: $CC_ARM"\n\
}\n\
\n\
build_updater() {\n\
    echo "=== Building SC1000 Updater ==="\n\
    if [ ! -f "$SC1000_DIR/software/xwax" ]; then\n\
        echo "Error: xwax binary not found. Build software first."\n\
        exit 1\n\
    fi\n\
    \n\
    # Create tarball directory if it does not exist\n\
    mkdir -p "$SC1000_DIR/updater/tarball"\n\
    \n\
    cd "$SC1000_DIR/updater"\n\
    ./buildupdater.sh\n\
    echo "Updater package created: $SC1000_DIR/updater/sc.tar"\n\
}\n\
\n\
clean_build() {\n\
    echo "=== Cleaning Build Artifacts (keeping persistent cache) ==="\n\
    [ -f "$SC1000_DIR/software/xwax" ] && cd "$SC1000_DIR/software" && make clean\n\
    [ -f "$SC1000_DIR/updater/sc.tar" ] && rm -f "$SC1000_DIR/updater/sc.tar"\n\
    echo "Clean completed (buildroot cache preserved)"\n\
}\n\
\n\
clean_all() {\n\
    echo "=== Cleaning All Build Artifacts INCLUDING persistent cache ==="\n\
    [ -d "$BUILDROOT_OUTPUT_DIR" ] && rm -rf "$BUILDROOT_OUTPUT_DIR"/*\n\
    [ -f "$SC1000_DIR/software/xwax" ] && cd "$SC1000_DIR/software" && make clean\n\
    [ -f "$SC1000_DIR/updater/sc.tar" ] && rm -f "$SC1000_DIR/updater/sc.tar"\n\
    # Remove symlink if it exists\n\
    [ -L "$BUILDROOT_DIR/output" ] && rm -f "$BUILDROOT_DIR/output"\n\
    echo "Complete clean finished (all caches removed)"\n\
}\n\
\n\
build_native() {\n\
    echo "=== Building SC1000 Software (Native) ==="\n\
    cd "$SC1000_DIR/software"\n\
    make clean || true\n\
    \n\
    # Cross-compiler not needed for native build\n\
    echo "Building xwax for native platform (for testing)..."\n\
    make CC=gcc\n\
    echo "Native build completed: $SC1000_DIR/software/xwax"\n\
}\n\
\n\
case "${1:-help}" in\n\
    os) build_os ;;\n\
    toolchain) build_toolchain_only ;;\n\
    software) build_software ;;\n\
    native) build_native ;;\n\
    updater) build_updater ;;\n\
    all) build_os && build_software && build_updater ;;\n\
    clean) clean_build ;;\n\
    clean-all) clean_all ;;\n\
    info) show_info ;;\n\
    shell) exec /bin/bash ;;\n\
    help|--help|-h|"") show_usage ;;\n\
    *) show_usage; exit 1 ;;\n\
esac\n\
' > /work/sc1000-build.sh

RUN chmod +x /work/sc1000-build.sh

ENTRYPOINT ["/work/sc1000-build.sh"]
CMD []
