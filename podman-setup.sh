#!/bin/bash
set -e

echo "=========================================="
echo "Podman Machine Setup for GPU Acceleration"
echo "=========================================="
echo ""

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed."
    echo "Please install Podman first:"
    echo "  brew install podman"
    exit 1
fi

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Warning: This setup is optimized for macOS M-series chips."
    echo "GPU acceleration may not work on other platforms."
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

echo ""
echo "=========================================="
echo "Podman Machine Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Copy .env.template to .env and configure your MongoDB URI"
echo "2. Run ./start.sh to start all services"
echo ""
