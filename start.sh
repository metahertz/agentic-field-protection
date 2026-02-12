#!/bin/bash
set -e

echo "=========================================="
echo "Starting LLM Container Stack"
echo "=========================================="
echo ""

# --- Secrets loading ---
# Priority: secrets file > environment variable > .env file
# Use MONGODB_URI_FILE to point to a file containing the URI,
# or place the file at secrets/mongodb_uri.

MONGODB_URI_FROM_FILE=""

# Check for secret file (MONGODB_URI_FILE env var or default path)
SECRETS_FILE="${MONGODB_URI_FILE:-secrets/mongodb_uri}"
if [ -f "$SECRETS_FILE" ]; then
    MONGODB_URI_FROM_FILE="$(cat "$SECRETS_FILE")"
    echo "Loading MONGODB_URI from secrets file: $SECRETS_FILE"
fi

# Check if .env exists (still needed for non-secret config)
if [ ! -f .env ]; then
    if [ -z "$MONGODB_URI_FROM_FILE" ] && [ -z "$MONGODB_URI" ]; then
        echo "Error: .env file not found!"
        echo ""
        echo "Please create .env from template:"
        echo "  cp .env.template .env"
        echo ""
        echo "Then edit .env and add your MongoDB connection string."
        echo ""
        echo "Alternatively, use a secrets file instead:"
        echo "  mkdir -p secrets && echo 'your-uri' > secrets/mongodb_uri"
        echo "  See Documentation/SECRETS.md for details."
        exit 1
    fi
fi

# Load environment variables from .env if it exists
if [ -f .env ]; then
    source .env
fi

# Secrets file takes priority over .env value
if [ -n "$MONGODB_URI_FROM_FILE" ]; then
    MONGODB_URI="$MONGODB_URI_FROM_FILE"
fi
export MONGODB_URI

# Warn if .env contains what appears to be real credentials
if [ -f .env ]; then
    ENV_MONGO_LINE=$(grep -E '^MONGODB_URI=' .env 2>/dev/null || true)
    if [ -n "$ENV_MONGO_LINE" ]; then
        # Check it's not the template placeholder
        if [[ "$ENV_MONGO_LINE" != *"username:password"* ]] && \
           [[ "$ENV_MONGO_LINE" != *"your-"* ]] && \
           [[ "$ENV_MONGO_LINE" =~ mongodb(\+srv)?:// ]]; then
            echo "WARNING: .env appears to contain real MongoDB credentials."
            echo "  Consider using a secrets file instead for better security:"
            echo "    mkdir -p secrets"
            echo "    grep '^MONGODB_URI=' .env | cut -d= -f2- > secrets/mongodb_uri"
            echo "    Then remove MONGODB_URI from .env"
            echo "  See Documentation/SECRETS.md for details."
            echo ""
        fi
    fi
fi

# Validate MongoDB URI
if [[ "$MONGODB_URI" == *"username:password"* ]] || [ -z "$MONGODB_URI" ]; then
    echo "Error: MONGODB_URI not configured"
    echo ""
    echo "Provide your MongoDB Atlas connection string via one of:"
    echo "  1. Secrets file:  mkdir -p secrets && echo 'your-uri' > secrets/mongodb_uri"
    echo "  2. Environment:   export MONGODB_URI='your-uri'"
    echo "  3. .env file:     Set MONGODB_URI in .env"
    echo ""
    echo "See Documentation/SECRETS.md for recommended approaches."
    exit 1
fi

# Ensure secrets file exists for podman-compose secrets support.
# If user provided URI via .env or env var (not a file), create the file.
if [ ! -f "$SECRETS_FILE" ]; then
    mkdir -p "$(dirname "$SECRETS_FILE")"
    printf '%s' "$MONGODB_URI" > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
fi

# Check if Podman is running
if ! podman machine list | grep -q "Currently running"; then
    echo "Starting Podman machine..."
    podman machine start
    sleep 5
fi

echo "Building containers..."
echo ""

# Build containers
podman-compose build

echo ""
echo "Starting services..."
echo ""

# Start all services
podman-compose up -d

echo ""
echo "Waiting for services to be ready..."
sleep 10

# Check service health
echo ""
echo "Service Status:"
echo "---------------"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Checking Ollama health..."
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "✓ Ollama is running"
else
    echo "✗ Ollama is not responding"
fi

echo ""
echo "Checking Open WebUI health..."
if curl -s http://localhost:${OPENWEBUI_PORT:-8080} > /dev/null; then
    echo "✓ Open WebUI is running"
else
    echo "✗ Open WebUI is not responding"
fi

echo ""
echo "=========================================="
echo "Services Started Successfully!"
echo "=========================================="
echo ""
echo "Access Open WebUI at: http://localhost:${OPENWEBUI_PORT:-8080}"
echo ""
echo "Downloading initial model (${OLLAMA_MODEL:-llama3.2:3b})..."
echo "This may take several minutes depending on your connection..."
echo ""

# Pull the default model
./scripts/pull-model.sh "${OLLAMA_MODEL:-llama3.2:3b}"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Quick Start:"
echo "1. Open http://localhost:${OPENWEBUI_PORT:-8080} in your browser"
echo "2. Start chatting with the LLM"
echo "3. Use MongoDB MCP tools by asking questions about your database"
echo ""
echo "Useful commands:"
echo "  ./scripts/logs.sh [service]  - View logs"
echo "  ./scripts/stop.sh            - Stop all services"
echo "  ./scripts/pull-model.sh      - Download additional models"
echo "  ./scripts/benchmark.sh       - Run performance tests"
echo ""
