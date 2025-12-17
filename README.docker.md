# SC1000 Docker Development Environment

Integrated Docker environment for SC1000 development and building. Enables efficient development with optimized multi-stage builds.

## Quick Start

```bash
# 1. Build image
docker build -t sc1000-dev .

# 2. Start development environment
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-dev

# 3. Or execute build directly
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev all
```

## Platform Support

**Apple Silicon (M1/M2/M3)**:
```bash
docker build -t sc1000-dev .  # Automatic ARM64 support
```

**Intel Mac/x86_64**:
```bash
docker build --build-arg PLATFORM=linux/amd64 -t sc1000-dev .
```

## Build Commands

### Integrated Build Tool
```bash
# Build everything (OS + Software + Updater)
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev all

# Individual builds
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev os        # Linux image
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev software  # xwax software
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev updater   # Updater package

# Clean build
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev clean
```

### Interactive Mode Development
```bash
# Start development shell
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-dev shell

# Manual build inside container
/work/sc1000-build.sh software  # Software only
/work/sc1000-build.sh updater   # Updater only
```

## Build Output

| Component | Output Location | Description |
|-----------|-----------------|-------------|
| OS Image | `/work/buildroot-2018.08.4/output/images/` | zImage, rootfs, *.dtb |
| xwax Binary | `/work/SC1000/software/xwax` | ARM executable |
| Updater | `/work/SC1000/updater/sc.tar` | Device update package |

### Copying SD Card Image

After building the OS, copy the SD card image to the repository:

```bash
# Copy sdcard.img from build output to os/ directory (using docker-compose for volume access)
docker-compose run --rm --entrypoint sh sc1000-dev -c \
  "cp /work/buildroot-output/images/sdcard.img /work/SC1000/os/sdcard.img"

# Optionally compress the image
gzip -k os/sdcard.img
```

## Performance & Notes

- **Initial OS build**: 1+ hours, ~10GB required
- **Software only**: Completes in minutes
- **Recommended resources**: 8GB+ RAM, 15GB+ disk space

## Troubleshooting

**Build errors**:
```bash
# Cross-compiler error → Build OS first
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev os

# Permission error → Environment variables auto-configured (FORCE_UNSAFE_CONFIGURE=1)

# Dependency error → Execute clean build
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev clean
```

**Development efficiency**:
```bash
# Skip OS build during software development
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev software

# Recreate only updater after configuration changes
docker run --rm -v $(pwd):/work/SC1000 sc1000-dev updater
```