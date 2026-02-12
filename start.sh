#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect container runtime (podman or docker)
# shellcheck source=scripts/detect-runtime.sh
source "$SCRIPT_DIR/scripts/detect-runtime.sh"

# --- Parse command-line arguments ---
# Usage: ./start.sh [--model MODEL] [--no-pull]
SKIP_PULL=false
CLI_MODEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            CLI_MODEL="$2"
            shift 2
            ;;
        --no-pull)
            SKIP_PULL=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./start.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --model MODEL  Specify the LLM model to pull on startup"
            echo "                 (default: OLLAMA_MODEL from .env, or llama3.2:3b)"
            echo "  --no-pull      Skip automatic model download on startup"
            echo "  --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./start.sh                           # Start with default model"
            echo "  ./start.sh --model mistral:7b        # Start with Mistral 7B"
            echo "  ./start.sh --no-pull                 # Start without pulling a model"
            echo "  OLLAMA_MODEL=phi3:3.8b ./start.sh    # Use env var"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run './start.sh --help' for usage."
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Starting LLM Container Stack ($RUNTIME_NAME)"
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

# Ensure secrets file exists for compose secrets support.
# If user provided URI via .env or env var (not a file), create the file.
if [ ! -f "$SECRETS_FILE" ]; then
    mkdir -p "$(dirname "$SECRETS_FILE")"
    printf '%s' "$MONGODB_URI" > "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
fi

# Start container runtime if needed
if [ "$CONTAINER_CMD" = "podman" ]; then
    if ! podman machine list | grep -q "Currently running"; then
        echo "Starting Podman machine..."
        podman machine start
        sleep 5
    fi
else
    if ! docker info &>/dev/null; then
        echo "Error: Docker is not running."
        echo "Please start Docker Desktop or the Docker daemon."
        exit 1
    fi
    echo "NOTE: Docker on macOS does not support GPU passthrough."
    echo "Ollama will run in CPU-only mode (expect 10-15 tokens/sec)."
    echo "For GPU acceleration, use Podman instead: brew install podman podman-compose"
    echo ""
fi

echo "Building containers..."
echo ""

# Build containers
$COMPOSE_CMD -f "$COMPOSE_FILE" build

echo ""
echo "Starting services..."
echo ""

# Start all services
$COMPOSE_CMD -f "$COMPOSE_FILE" up -d

echo ""
echo "Waiting for services to be ready..."
sleep 10

# Check service health
echo ""
echo "Service Status:"
echo "---------------"
$CONTAINER_CMD ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

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
# Determine which model to use: CLI flag > env var > .env default > hardcoded default
SELECTED_MODEL="${CLI_MODEL:-${OLLAMA_MODEL:-llama3.2:3b}}"

if [ "$SKIP_PULL" = true ]; then
    echo ""
    echo "Skipping model download (--no-pull specified)."
    echo "Pull a model later with: ./scripts/pull-model.sh $SELECTED_MODEL"
else
    echo ""
    echo "Downloading model ($SELECTED_MODEL)..."
    echo "This may take several minutes depending on your connection..."
    echo ""

    # Pull the selected model
    ./scripts/pull-model.sh "$SELECTED_MODEL"
fi

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
echo "  ./scripts/pull-model.sh --list - List downloaded models"
echo "  ./scripts/benchmark.sh       - Run performance tests"
echo ""
echo "To switch models without restarting:"
echo "  ./scripts/pull-model.sh <model-name>"
echo "  Then select the new model in Open WebUI"
echo ""
