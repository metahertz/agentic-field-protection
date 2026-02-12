#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/detect-runtime.sh
source "$SCRIPT_DIR/scripts/detect-runtime.sh"

echo "=========================================="
echo "LLM Container Stack - Integration Tests ($RUNTIME_NAME)"
echo "=========================================="
echo ""

FAILED=0

# Test 1: Check container runtime is running
echo "[1/7] Checking $RUNTIME_NAME..."
if [ "$CONTAINER_CMD" = "podman" ]; then
    if podman machine list | grep -q "Currently running"; then
        echo "✓ Podman machine is running"
    else
        echo "✗ Podman machine is not running"
        echo "  Run: ./podman-setup.sh"
        FAILED=$((FAILED + 1))
    fi
else
    if docker info &>/dev/null; then
        echo "✓ Docker daemon is running"
    else
        echo "✗ Docker daemon is not running"
        echo "  Start Docker Desktop or the Docker daemon"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# Test 2: Check containers are running
echo "[2/7] Checking containers..."
CONTAINERS=$($CONTAINER_CMD ps --format "{{.Names}}")
for service in ollama openwebui mcp-mongodb; do
    if echo "$CONTAINERS" | grep -q "$service"; then
        echo "✓ $service is running"
    else
        echo "✗ $service is not running"
        FAILED=$((FAILED + 1))
    fi
done
echo ""

# Test 3: Test GPU acceleration
echo "[3/7] Testing GPU acceleration..."
if [ "$RUNTIME_HAS_GPU" = "true" ]; then
    if $CONTAINER_CMD exec ollama ls /dev/dri 2>/dev/null | grep -q "renderD128"; then
        echo "✓ GPU device detected in Ollama container"
    else
        echo "⚠ GPU device not found - may be using CPU only"
    fi
else
    echo "⚠ GPU not available with Docker on macOS - using CPU only"
fi
echo ""

# Test 4: Test Ollama API
echo "[4/7] Testing Ollama API..."
if curl -sf http://localhost:11434/api/tags > /dev/null; then
    echo "✓ Ollama API is responding"
    MODELS=$(curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | wc -l)
    echo "  Models available: $MODELS"
else
    echo "✗ Ollama API is not responding"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 5: Test Open WebUI
echo "[5/7] Testing Open WebUI..."
if [ -f .env ]; then
    source .env
fi
PORT=${OPENWEBUI_PORT:-8080}
if curl -sf http://localhost:$PORT > /dev/null; then
    echo "✓ Open WebUI is responding on port $PORT"
else
    echo "✗ Open WebUI is not responding"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 6: Test MCP Server
echo "[6/7] Testing MongoDB MCP server..."
MCP_PORT=${MCP_PORT:-3000}
if $CONTAINER_CMD exec mcp-mongodb node -e "console.log('ok')" 2>/dev/null | grep -q "ok"; then
    echo "✓ MCP server container is functional"
else
    echo "✗ MCP server container has issues"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 7: Test end-to-end inference
echo "[7/7] Testing LLM inference..."
RESPONSE=$(curl -s http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Say only the word test",
  "stream": false
}' 2>/dev/null)

if echo "$RESPONSE" | grep -q '"response"'; then
    echo "✓ LLM inference working"
    TOKENS=$(echo "$RESPONSE" | grep -o '"eval_count":[0-9]*' | cut -d':' -f2)
    DURATION=$(echo "$RESPONSE" | grep -o '"eval_duration":[0-9]*' | cut -d':' -f2)
    if [ -n "$TOKENS" ] && [ -n "$DURATION" ]; then
        TPS=$(echo "scale=2; $TOKENS * 1000000000 / $DURATION" | bc 2>/dev/null || echo "N/A")
        echo "  Performance: $TPS tokens/sec"
    fi
else
    echo "✗ LLM inference failed"
    echo "  Make sure a model is loaded (run ./scripts/pull-model.sh)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Summary
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
else
    echo "✗ $FAILED test(s) failed"
fi
echo "=========================================="
echo ""

if [ $FAILED -gt 0 ]; then
    echo "Troubleshooting:"
    echo "1. Check logs: ./scripts/logs.sh"
    echo "2. Verify .env configuration"
    echo "3. Restart services: ./scripts/stop.sh && ./start.sh"
    echo ""
    exit 1
fi

exit 0
