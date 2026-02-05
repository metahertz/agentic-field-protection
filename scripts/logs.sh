#!/bin/bash

SERVICE=${1:-all}

if [ "$SERVICE" = "all" ]; then
    echo "Showing logs for all services (Ctrl+C to exit)..."
    echo ""
    podman-compose logs -f
elif [ "$SERVICE" = "ollama" ] || [ "$SERVICE" = "openwebui" ] || [ "$SERVICE" = "mcp" ]; then
    echo "Showing logs for $SERVICE (Ctrl+C to exit)..."
    echo ""
    podman logs -f "$SERVICE"
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
