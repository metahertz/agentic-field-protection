#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/detect-runtime.sh
source "$SCRIPT_DIR/detect-runtime.sh"

echo "=========================================="
echo "Health Check - LLM Container Stack ($RUNTIME_NAME)"
echo "=========================================="
echo ""

# Function to check service
check_service() {
    local name=$1
    local url=$2

    if curl -sf "$url" > /dev/null 2>&1; then
        echo "✓ $name is healthy"
        return 0
    else
        echo "✗ $name is not responding"
        return 1
    fi
}

# Function to check container
check_container() {
    local name=$1

    if $CONTAINER_CMD ps --format "{{.Names}}" | grep -q "^${name}$"; then
        STATUS=$($CONTAINER_CMD ps --format "{{.Names}}\t{{.Status}}" | grep "^${name}" | cut -f2)
        echo "✓ $name: $STATUS"
        return 0
    else
        echo "✗ $name is not running"
        return 1
    fi
}

FAILURES=0

# Detect platform
OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux)  PLATFORM="linux" ;;
    *)      PLATFORM="unknown" ;;
esac

# Check container runtime
echo "$RUNTIME_NAME:"
if [ "$CONTAINER_CMD" = "podman" ]; then
    if [ "$PLATFORM" = "macos" ]; then
        if podman machine list 2>/dev/null | grep -q "Currently running"; then
            echo "✓ Podman machine is running"
        else
            echo "✗ Podman machine is not running"
            FAILURES=$((FAILURES + 1))
        fi
    elif [ "$PLATFORM" = "linux" ]; then
        if podman info &> /dev/null; then
            echo "✓ Podman is available (native Linux)"
        else
            echo "✗ Podman is not working"
            FAILURES=$((FAILURES + 1))
        fi
    fi
else
    if docker info &>/dev/null; then
        echo "✓ Docker daemon is running"
    else
        echo "✗ Docker daemon is not running"
        FAILURES=$((FAILURES + 1))
    fi
fi
echo ""

# Check containers
echo "Containers:"
check_container "ollama" || FAILURES=$((FAILURES + 1))
check_container "openwebui" || FAILURES=$((FAILURES + 1))
check_container "mcp-mongodb" || FAILURES=$((FAILURES + 1))
echo ""

# Check services
echo "Services:"
check_service "Ollama API" "http://localhost:11434/api/tags" || FAILURES=$((FAILURES + 1))

if [ -f .env ]; then
    source .env
fi
check_service "Open WebUI" "http://localhost:${OPENWEBUI_PORT:-8080}" || FAILURES=$((FAILURES + 1))
echo ""

# Check models
echo "Models:"
MODELS=$(curl -s http://localhost:11434/api/tags 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
if [ -n "$MODELS" ]; then
    echo "$MODELS" | while read -r model; do
        echo "  • $model"
    done
else
    echo "  No models loaded"
    echo "  Run: ./scripts/pull-model.sh llama3.2:3b"
fi
echo ""

# Check GPU
echo "GPU Acceleration:"
if [ "$RUNTIME_HAS_GPU" = "true" ]; then
    if $CONTAINER_CMD exec ollama ls /dev/dri 2>/dev/null | grep -q "renderD128"; then
        echo "✓ GPU device available"
    else
        echo "⚠ GPU device not found (using CPU)"
    fi
else
    echo "⚠ Not available with Docker on macOS (using CPU)"
fi
echo ""

# Summary
echo "=========================================="
if [ $FAILURES -eq 0 ]; then
    echo "✓ System is healthy"
    exit 0
else
    echo "✗ Found $FAILURES issue(s)"
    echo ""
    echo "Run './scripts/logs.sh' to investigate"
    exit 1
fi
