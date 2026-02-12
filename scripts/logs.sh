#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/detect-runtime.sh
source "$SCRIPT_DIR/detect-runtime.sh"

SERVICE=${1:-all}

if [ "$SERVICE" = "all" ]; then
    echo "Showing logs for all services (Ctrl+C to exit)..."
    echo ""
    $COMPOSE_CMD -f "$SCRIPT_DIR/../$COMPOSE_FILE" logs -f
elif [ "$SERVICE" = "ollama" ] || [ "$SERVICE" = "openwebui" ] || [ "$SERVICE" = "mcp" ]; then
    echo "Showing logs for $SERVICE (Ctrl+C to exit)..."
    echo ""
    $CONTAINER_CMD logs -f "$SERVICE"
else
    echo "Usage: $0 [service]"
    echo ""
    echo "Available services:"
    echo "  all       - All services (default)"
    echo "  ollama    - Ollama LLM runtime"
    echo "  openwebui - Open WebUI interface"
    echo "  mcp       - MongoDB MCP server"
    exit 1
fi
