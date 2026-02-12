#!/bin/bash
set -e

# check-benchmarks.sh — Compare benchmark results against baselines and flag regressions
#
# Usage:
#   ./scripts/check-benchmarks.sh <results-file> [--baselines <baselines-file>]
#   ./scripts/check-benchmarks.sh --validate-baselines [--baselines <baselines-file>]
#
# The results file is a JSON file with the structure produced by benchmark.sh --json.
# When --validate-baselines is passed, only validates the baselines config (no results needed).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINES_FILE="${REPO_ROOT}/benchmarks/baselines.json"
RESULTS_FILE=""
VALIDATE_ONLY=false

usage() {
    echo "Usage: $0 <results-file> [--baselines <file>]"
    echo "       $0 --validate-baselines [--baselines <file>]"
    echo ""
    echo "Options:"
    echo "  --baselines <file>       Path to baselines JSON (default: benchmarks/baselines.json)"
    echo "  --validate-baselines     Only validate baselines config, no comparison"
    echo "  -h, --help               Show this help"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --baselines)
            BASELINES_FILE="$2"
            shift 2
            ;;
        --validate-baselines)
            VALIDATE_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage
            ;;
        *)
            RESULTS_FILE="$1"
            shift
            ;;
    esac
done

# Require jq for JSON processing
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: sudo apt-get install -y jq (Linux) or brew install jq (macOS)"
    exit 1
fi

echo "=========================================="
echo "Benchmark Regression Check"
echo "=========================================="
echo ""

# Validate baselines file exists and is valid JSON
validate_baselines() {
    echo "Validating baselines: ${BASELINES_FILE}"

    if [ ! -f "$BASELINES_FILE" ]; then
        echo "FAIL: Baselines file not found: ${BASELINES_FILE}"
        return 1
    fi

    if ! jq empty "$BASELINES_FILE" 2>/dev/null; then
        echo "FAIL: Baselines file is not valid JSON"
        return 1
    fi

    # Check required top-level keys
    local version models thresholds
    version=$(jq -r '.version // empty' "$BASELINES_FILE")
    models=$(jq -r '.models // empty' "$BASELINES_FILE")
    thresholds=$(jq -r '.thresholds // empty' "$BASELINES_FILE")

    if [ -z "$version" ]; then
        echo "FAIL: Missing 'version' field in baselines"
        return 1
    fi

    if [ -z "$models" ]; then
        echo "FAIL: Missing 'models' field in baselines"
        return 1
    fi

    if [ -z "$thresholds" ]; then
        echo "FAIL: Missing 'thresholds' field in baselines"
        return 1
    fi

    # Validate each model has required structure
    local model_count
    model_count=$(jq '.models | keys | length' "$BASELINES_FILE")
    echo "  Found ${model_count} model baseline(s)"

    local errors=0
    while IFS= read -r model; do
        # Check token_generation exists with gpu and cpu
        for env in gpu cpu; do
            local min max
            min=$(jq -r ".models[\"${model}\"].token_generation.${env}.min_tokens_per_sec // empty" "$BASELINES_FILE")
            max=$(jq -r ".models[\"${model}\"].token_generation.${env}.max_tokens_per_sec // empty" "$BASELINES_FILE")

            if [ -z "$min" ] || [ -z "$max" ]; then
                echo "  FAIL: ${model} missing token_generation.${env} min/max"
                errors=$((errors + 1))
                continue
            fi

            if [ "$(echo "$min > $max" | bc -l)" -eq 1 ]; then
                echo "  FAIL: ${model} token_generation.${env} min ($min) > max ($max)"
                errors=$((errors + 1))
            fi
        done

        # Check prompt_processing exists with gpu and cpu
        for env in gpu cpu; do
            local min max
            min=$(jq -r ".models[\"${model}\"].prompt_processing.${env}.min_tokens_per_sec // empty" "$BASELINES_FILE")
            max=$(jq -r ".models[\"${model}\"].prompt_processing.${env}.max_tokens_per_sec // empty" "$BASELINES_FILE")

            if [ -z "$min" ] || [ -z "$max" ]; then
                echo "  FAIL: ${model} missing prompt_processing.${env} min/max"
                errors=$((errors + 1))
                continue
            fi

            if [ "$(echo "$min > $max" | bc -l)" -eq 1 ]; then
                echo "  FAIL: ${model} prompt_processing.${env} min ($min) > max ($max)"
                errors=$((errors + 1))
            fi
        done

        echo "  OK: ${model}"
    done < <(jq -r '.models | keys[]' "$BASELINES_FILE")

    # Validate tolerance
    local tolerance
    tolerance=$(jq -r '.thresholds.regression_tolerance_pct // empty' "$BASELINES_FILE")
    if [ -z "$tolerance" ]; then
        echo "  FAIL: Missing thresholds.regression_tolerance_pct"
        errors=$((errors + 1))
    else
        echo "  Regression tolerance: ${tolerance}%"
    fi

    if [ "$errors" -gt 0 ]; then
        echo ""
        echo "FAIL: ${errors} validation error(s) found"
        return 1
    fi

    echo ""
    echo "OK: Baselines validation passed"
    return 0
}

# Compare results against baselines
compare_results() {
    local results_file="$1"

    echo "Comparing results: ${results_file}"
    echo "Against baselines: ${BASELINES_FILE}"
    echo ""

    if [ ! -f "$results_file" ]; then
        echo "FAIL: Results file not found: ${results_file}"
        return 1
    fi

    if ! jq empty "$results_file" 2>/dev/null; then
        echo "FAIL: Results file is not valid JSON"
        return 1
    fi

    local tolerance
    tolerance=$(jq -r '.thresholds.regression_tolerance_pct' "$BASELINES_FILE")

    local model env_type
    model=$(jq -r '.model // empty' "$results_file")
    env_type=$(jq -r '.environment // "cpu"' "$results_file")

    if [ -z "$model" ]; then
        echo "FAIL: Results file missing 'model' field"
        return 1
    fi

    echo "Model: ${model}"
    echo "Environment: ${env_type}"
    echo ""

    # Check if model exists in baselines
    local baseline_exists
    baseline_exists=$(jq -r ".models[\"${model}\"] // empty" "$BASELINES_FILE")
    if [ -z "$baseline_exists" ]; then
        echo "WARN: No baseline defined for model '${model}'"
        echo "  Skipping regression check (add baseline to benchmarks/baselines.json)"
        return 0
    fi

    local regressions=0

    # Check token generation rate
    local actual_tps baseline_min
    actual_tps=$(jq -r '.token_generation.tokens_per_sec // empty' "$results_file")
    baseline_min=$(jq -r ".models[\"${model}\"].token_generation.${env_type}.min_tokens_per_sec // empty" "$BASELINES_FILE")

    if [ -n "$actual_tps" ] && [ -n "$baseline_min" ]; then
        local threshold
        threshold=$(echo "scale=2; $baseline_min * (100 - $tolerance) / 100" | bc)

        echo "Token generation: ${actual_tps} tokens/sec"
        echo "  Baseline min: ${baseline_min} tokens/sec (threshold with ${tolerance}% tolerance: ${threshold})"

        if [ "$(echo "$actual_tps < $threshold" | bc -l)" -eq 1 ]; then
            echo "  REGRESSION: Token generation ${actual_tps} t/s is below threshold ${threshold} t/s"
            regressions=$((regressions + 1))
        else
            echo "  OK"
        fi
    else
        echo "WARN: Could not compare token generation (missing data)"
    fi

    # Check prompt processing rate
    local actual_pps baseline_pps_min
    actual_pps=$(jq -r '.prompt_processing.tokens_per_sec // empty' "$results_file")
    baseline_pps_min=$(jq -r ".models[\"${model}\"].prompt_processing.${env_type}.min_tokens_per_sec // empty" "$BASELINES_FILE")

    if [ -n "$actual_pps" ] && [ -n "$baseline_pps_min" ]; then
        local pps_threshold
        pps_threshold=$(echo "scale=2; $baseline_pps_min * (100 - $tolerance) / 100" | bc)

        echo "Prompt processing: ${actual_pps} tokens/sec"
        echo "  Baseline min: ${baseline_pps_min} tokens/sec (threshold with ${tolerance}% tolerance: ${pps_threshold})"

        if [ "$(echo "$actual_pps < $pps_threshold" | bc -l)" -eq 1 ]; then
            echo "  REGRESSION: Prompt processing ${actual_pps} t/s is below threshold ${pps_threshold} t/s"
            regressions=$((regressions + 1))
        else
            echo "  OK"
        fi
    else
        echo "WARN: Could not compare prompt processing (missing data)"
    fi

    echo ""

    if [ "$regressions" -gt 0 ]; then
        echo "=========================================="
        echo "FAIL: ${regressions} regression(s) detected"
        echo "=========================================="
        return 1
    fi

    echo "=========================================="
    echo "OK: No regressions detected"
    echo "=========================================="
    return 0
}

# Main
if ! validate_baselines; then
    exit 1
fi

if [ "$VALIDATE_ONLY" = true ]; then
    exit 0
fi

if [ -z "$RESULTS_FILE" ]; then
    echo ""
    echo "Error: No results file specified (use --validate-baselines for config-only check)"
    usage
fi

echo ""
compare_results "$RESULTS_FILE"
