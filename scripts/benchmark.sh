#!/bin/bash
set -e

# benchmark.sh — LLM performance benchmark
#
# Usage:
#   ./scripts/benchmark.sh                  Run benchmark against live Ollama
#   ./scripts/benchmark.sh --dry-run        Validate config without running inference
#   ./scripts/benchmark.sh --json           Output results as JSON (for regression checks)
#   ./scripts/benchmark.sh --dry-run --json Output sample results as JSON (for CI testing)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--json]"
            echo ""
            echo "Options:"
            echo "  --dry-run   Validate config without running inference (CI-safe)"
            echo "  --json      Output results in JSON format for regression checks"
            echo "  -h, --help  Show this help"
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            exit 1
            ;;
    esac
done

# Load environment to get model name
if [ -f "${REPO_ROOT}/.env" ]; then
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/.env"
fi

MODEL=${OLLAMA_MODEL:-llama3.2:3b}

# --- Dry-run mode: validate config and output sample data ---
if [ "$DRY_RUN" = true ]; then
    # When JSON output is requested, send diagnostics to stderr so stdout is clean JSON
    if [ "$JSON_OUTPUT" = true ]; then
        LOG_FD=2
    else
        LOG_FD=1
    fi

    echo "==========================================" >&"$LOG_FD"
    echo "LLM Performance Benchmark (dry-run)" >&"$LOG_FD"
    echo "==========================================" >&"$LOG_FD"
    echo "" >&"$LOG_FD"

    # Validate baselines file exists
    BASELINES="${REPO_ROOT}/benchmarks/baselines.json"
    if [ ! -f "$BASELINES" ]; then
        echo "FAIL: Baselines file not found: ${BASELINES}" >&2
        exit 1
    fi

    # Validate baselines is valid JSON (requires jq)
    if command -v jq &>/dev/null; then
        if ! jq empty "$BASELINES" 2>/dev/null; then
            echo "FAIL: Baselines file is not valid JSON" >&2
            exit 1
        fi
        echo "OK: Baselines file is valid JSON" >&"$LOG_FD"

        # Check that the configured model has a baseline
        MODEL_BASELINE=$(jq -r ".models[\"${MODEL}\"] // empty" "$BASELINES")
        if [ -n "$MODEL_BASELINE" ]; then
            echo "OK: Baseline found for model '${MODEL}'" >&"$LOG_FD"
        else
            echo "WARN: No baseline found for model '${MODEL}'" >&"$LOG_FD"
        fi

        MODEL_COUNT=$(jq '.models | keys | length' "$BASELINES")
        echo "OK: ${MODEL_COUNT} model baseline(s) defined" >&"$LOG_FD"
    else
        echo "WARN: jq not installed, skipping JSON validation" >&"$LOG_FD"
    fi

    # Validate benchmark script itself (syntax check)
    if bash -n "${BASH_SOURCE[0]}"; then
        echo "OK: Benchmark script syntax valid" >&"$LOG_FD"
    else
        echo "FAIL: Benchmark script has syntax errors" >&2
        exit 1
    fi

    # Validate check-benchmarks.sh exists and has valid syntax
    CHECK_SCRIPT="${SCRIPT_DIR}/check-benchmarks.sh"
    if [ -f "$CHECK_SCRIPT" ]; then
        if bash -n "$CHECK_SCRIPT"; then
            echo "OK: check-benchmarks.sh syntax valid" >&"$LOG_FD"
        else
            echo "FAIL: check-benchmarks.sh has syntax errors" >&2
            exit 1
        fi
    else
        echo "WARN: check-benchmarks.sh not found" >&"$LOG_FD"
    fi

    echo "" >&"$LOG_FD"

    # In dry-run + JSON mode, output sample results for CI testing
    if [ "$JSON_OUTPUT" = true ]; then
        if command -v jq &>/dev/null; then
            # Generate sample results within baseline ranges for the configured model
            SAMPLE_TPS=$(jq -r ".models[\"${MODEL}\"].token_generation.cpu.min_tokens_per_sec // 10" "$BASELINES")
            SAMPLE_PPS=$(jq -r ".models[\"${MODEL}\"].prompt_processing.cpu.min_tokens_per_sec // 20" "$BASELINES")
        else
            SAMPLE_TPS=10
            SAMPLE_PPS=25
        fi

        cat <<ENDJSON
{
  "model": "${MODEL}",
  "environment": "cpu",
  "dry_run": true,
  "token_generation": {
    "tokens_per_sec": ${SAMPLE_TPS},
    "eval_count": 50
  },
  "prompt_processing": {
    "tokens_per_sec": ${SAMPLE_PPS},
    "prompt_eval_count": 10
  }
}
ENDJSON
    fi

    echo "" >&"$LOG_FD"
    echo "Dry-run complete. All validations passed." >&"$LOG_FD"
    exit 0
fi

# --- Live benchmark mode ---
echo "=========================================="
echo "LLM Performance Benchmark"
echo "=========================================="
echo ""

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "Error: Ollama is not running."
    echo "Please start the services first with ./start.sh"
    exit 1
fi

echo "Testing model: $MODEL"
echo ""

# Check GPU acceleration
echo "Checking GPU acceleration..."
echo ""
GPU_INFO=$(podman exec ollama sh -c 'if command -v vulkaninfo >/dev/null 2>&1; then vulkaninfo | grep -A5 "GPU"; else echo "vulkaninfo not available"; fi' 2>&1 || echo "Could not check GPU info")
echo "$GPU_INFO"
echo ""

# Determine environment type based on GPU availability
ENV_TYPE="cpu"
if echo "$GPU_INFO" | grep -qi "gpu\|vulkan\|venus"; then
    ENV_TYPE="gpu"
fi

# Test prompt processing speed
echo "Running inference test..."
echo "Prompt: 'Write a haiku about containers'"
echo ""

START=$(date +%s.%N)

RESPONSE=$(curl -s http://localhost:11434/api/generate -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"Write a haiku about containers\",
  \"stream\": false
}")

END=$(date +%s.%N)

ELAPSED=$(echo "$END - $START" | bc)

# Extract metrics from response
TOTAL_DURATION=$(echo "$RESPONSE" | grep -o '"total_duration":[0-9]*' | cut -d':' -f2)
LOAD_DURATION=$(echo "$RESPONSE" | grep -o '"load_duration":[0-9]*' | cut -d':' -f2)
PROMPT_EVAL_COUNT=$(echo "$RESPONSE" | grep -o '"prompt_eval_count":[0-9]*' | cut -d':' -f2)
PROMPT_EVAL_DURATION=$(echo "$RESPONSE" | grep -o '"prompt_eval_duration":[0-9]*' | cut -d':' -f2)
EVAL_COUNT=$(echo "$RESPONSE" | grep -o '"eval_count":[0-9]*' | cut -d':' -f2)
EVAL_DURATION=$(echo "$RESPONSE" | grep -o '"eval_duration":[0-9]*' | cut -d':' -f2)

# Calculate rates
TOKENS_PER_SEC=""
PROMPT_TOKENS_PER_SEC=""

if [ -n "$EVAL_COUNT" ] && [ -n "$EVAL_DURATION" ] && [ "$EVAL_DURATION" -gt 0 ]; then
    TOKENS_PER_SEC=$(echo "scale=2; $EVAL_COUNT * 1000000000 / $EVAL_DURATION" | bc)
fi

if [ -n "$PROMPT_EVAL_COUNT" ] && [ -n "$PROMPT_EVAL_DURATION" ] && [ "$PROMPT_EVAL_DURATION" -gt 0 ]; then
    PROMPT_TOKENS_PER_SEC=$(echo "scale=2; $PROMPT_EVAL_COUNT * 1000000000 / $PROMPT_EVAL_DURATION" | bc)
fi

# JSON output mode
if [ "$JSON_OUTPUT" = true ]; then
    cat <<ENDJSON
{
  "model": "${MODEL}",
  "environment": "${ENV_TYPE}",
  "dry_run": false,
  "total_time_sec": ${ELAPSED},
  "token_generation": {
    "tokens_per_sec": ${TOKENS_PER_SEC:-null},
    "eval_count": ${EVAL_COUNT:-null},
    "eval_duration_ns": ${EVAL_DURATION:-null}
  },
  "prompt_processing": {
    "tokens_per_sec": ${PROMPT_TOKENS_PER_SEC:-null},
    "prompt_eval_count": ${PROMPT_EVAL_COUNT:-null},
    "prompt_eval_duration_ns": ${PROMPT_EVAL_DURATION:-null}
  },
  "total_duration_ns": ${TOTAL_DURATION:-null},
  "load_duration_ns": ${LOAD_DURATION:-null}
}
ENDJSON
    exit 0
fi

# Human-readable output
echo ""
echo "=========================================="
echo "Benchmark Results"
echo "=========================================="
echo ""
echo "Model: $MODEL"
echo "Total time: ${ELAPSED}s"
echo ""

if [ -n "$TOTAL_DURATION" ]; then
    TOTAL_SEC=$(echo "scale=2; $TOTAL_DURATION / 1000000000" | bc)
    echo "Total duration: ${TOTAL_SEC}s"
fi

if [ -n "$LOAD_DURATION" ]; then
    LOAD_SEC=$(echo "scale=2; $LOAD_DURATION / 1000000000" | bc)
    echo "Model load time: ${LOAD_SEC}s"
fi

if [ -n "$PROMPT_TOKENS_PER_SEC" ]; then
    echo "Prompt processing: $PROMPT_EVAL_COUNT tokens at ${PROMPT_TOKENS_PER_SEC} tokens/sec"
fi

if [ -n "$TOKENS_PER_SEC" ]; then
    echo "Token generation: $EVAL_COUNT tokens at ${TOKENS_PER_SEC} tokens/sec"
fi

echo ""
echo "Performance Profile:"
if [ -n "$TOKENS_PER_SEC" ]; then
    if (( $(echo "$TOKENS_PER_SEC > 70" | bc -l) )); then
        echo "  Excellent - Likely using GPU acceleration"
    elif (( $(echo "$TOKENS_PER_SEC > 40" | bc -l) )); then
        echo "  Good - GPU acceleration active with some overhead"
    elif (( $(echo "$TOKENS_PER_SEC > 15" | bc -l) )); then
        echo "  Moderate - May be CPU-only or suboptimal GPU setup"
    else
        echo "  Slow - Likely CPU-only mode"
    fi
fi

echo ""
echo "Expected performance (M2/M3 Mac with $MODEL):"
echo "  Native Metal: 80-100 tokens/sec"
echo "  Podman GPU:   50-70 tokens/sec"
echo "  CPU-only:     10-15 tokens/sec"
echo ""
