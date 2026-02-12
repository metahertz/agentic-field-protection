#!/bin/bash

echo "Stopping LLM Container Stack..."
echo ""

# Stop all services
podman-compose down

echo ""
echo "All services stopped."
echo ""
echo "To completely remove all data, run:"
echo "  podman volume prune"
echo ""
