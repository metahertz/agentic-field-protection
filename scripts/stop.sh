#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/detect-runtime.sh
source "$SCRIPT_DIR/detect-runtime.sh"

echo "Stopping LLM Container Stack ($RUNTIME_NAME)..."
echo ""

# Stop all services
$COMPOSE_CMD -f "$SCRIPT_DIR/../$COMPOSE_FILE" down

echo ""
echo "All services stopped."
echo ""
echo "To completely remove all data, run:"
echo "  $CONTAINER_CMD volume prune"
echo ""
