#!/bin/bash
set -e

echo "=========================================="
echo "Podman Setup for GPU Acceleration"
echo "=========================================="
echo ""

# --- Platform detection ---
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux)  PLATFORM="linux" ;;
    *)      PLATFORM="unknown" ;;
esac

# Normalize architecture names
case "$ARCH" in
    arm64|aarch64) ARCH="arm64" ;;
    x86_64|amd64)  ARCH="x86_64" ;;
esac

echo "Detected platform: ${OS} ${ARCH}"
echo ""

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed."
    echo "Please install Podman first:"
    if [ "$PLATFORM" = "macos" ]; then
        echo "  brew install podman podman-compose"
    elif [ "$PLATFORM" = "linux" ]; then
        echo "  # Fedora/RHEL:"
        echo "  sudo dnf install podman podman-compose"
        echo ""
        echo "  # Ubuntu/Debian:"
        echo "  sudo apt install podman"
        echo "  pip install podman-compose"
    else
        echo "  See https://podman.io/getting-started/installation"
    fi
    exit 1
fi

echo "Podman version: $(podman --version)"
echo ""

# =========================================================================
# macOS Setup — Podman Machine with GPU via Vulkan-to-Metal (virtio-gpu Venus)
# =========================================================================
if [ "$PLATFORM" = "macos" ]; then
    if [[ "$ARCH" != "arm64" ]]; then
        echo "Warning: GPU acceleration is optimized for Apple Silicon (M1/M2/M3)."
        echo "Performance may vary on Intel Macs."
        echo ""
    fi

    # Stop existing Podman machine if running
    if podman machine list | grep -q "Currently running"; then
        echo "Stopping existing Podman machine..."
        podman machine stop || true
    fi

    # Remove existing machine if it exists
    if podman machine list | grep -q "podman-machine-default"; then
        echo "Removing existing Podman machine..."
        podman machine rm -f podman-machine-default || true
    fi

    echo ""
    echo "Creating new Podman machine with GPU support..."
    echo "This may take a few minutes..."
    echo ""

    # Create Podman machine with libkrun provider for GPU acceleration
    # Note: libkrun provider enables virtio-gpu Venus for Vulkan-to-Metal translation
    podman machine init \
        --cpus 4 \
        --memory 8192 \
        --disk-size 50 \
        --rootful \
        --now

    echo ""
    echo "Starting Podman machine..."
    podman machine start || true

    echo ""
    echo "Verifying Podman machine status..."
    podman machine list

    echo ""
    echo "Testing GPU device availability..."
    podman run --rm --device /dev/dri alpine ls -la /dev/dri || echo "Warning: GPU device not detected in container"

# =========================================================================
# Linux Setup — Native Podman with direct GPU access (no VM needed)
# =========================================================================
elif [ "$PLATFORM" = "linux" ]; then
    echo "Linux detected — Podman runs natively (no VM required)."
    echo ""

    # Check for GPU device availability
    if [ -d /dev/dri ]; then
        echo "GPU devices found:"
        ls -la /dev/dri/
        echo ""
    else
        echo "Warning: /dev/dri not found. GPU acceleration will not be available."
        echo "The system will fall back to CPU-only mode."
        echo ""
        echo "For ARM64 Linux GPU support, ensure your GPU drivers are installed:"
        echo "  # Qualcomm/Freedreno, Mali/Panfrost, Broadcom/V3D, etc."
        echo "  sudo apt install mesa-vulkan-drivers  # Debian/Ubuntu"
        echo "  sudo dnf install mesa-vulkan-drivers  # Fedora/RHEL"
        echo ""
    fi

    # Check for Vulkan support on the host
    if command -v vulkaninfo &> /dev/null; then
        echo "Vulkan support detected on host:"
        vulkaninfo --summary 2>/dev/null | head -20 || echo "  (could not query Vulkan details)"
        echo ""
    else
        echo "Note: vulkaninfo not found on host. Install vulkan-tools to verify GPU support."
        echo ""
    fi

    # Verify the current user has access to the render group (for /dev/dri)
    if [ -e /dev/dri/renderD128 ]; then
        if [ -r /dev/dri/renderD128 ] && [ -w /dev/dri/renderD128 ]; then
            echo "GPU render device is accessible by current user."
        else
            echo "Warning: /dev/dri/renderD128 exists but may not be accessible."
            echo "You may need to add your user to the 'render' or 'video' group:"
            echo "  sudo usermod -aG render \$USER"
            echo "  sudo usermod -aG video \$USER"
            echo "Then log out and back in."
            echo ""
        fi
    fi

    # Test GPU access inside a container
    echo "Testing GPU device access inside a container..."
    podman run --rm --device /dev/dri alpine ls -la /dev/dri 2>/dev/null \
        || echo "Warning: GPU device not accessible inside container"

else
    echo "Warning: Unsupported platform ($OS)."
    echo "This setup supports macOS (Apple Silicon) and ARM64 Linux."
    echo "GPU acceleration may not work."
fi

echo ""
echo "=========================================="
echo "Podman Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Copy .env.template to .env and configure your MongoDB URI"
echo "2. Run ./start.sh to start all services"
echo ""
