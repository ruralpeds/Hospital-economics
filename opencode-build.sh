#!/bin/bash
# =============================================================================
# Rural Hospital Economics Platform — OpenCode Build Script
# Target: macOS (Apple Silicon), Mac Studio, 36 GB unified memory
# AI model: Gemma 4 27B via Ollama (local, no API key required)
#
# Usage:
#   chmod +x opencode-build.sh
#   ./opencode-build.sh           # full setup + launch opencode
#   ./opencode-build.sh setup     # install deps only, do not launch
#   ./opencode-build.sh launch    # launch opencode (assumes setup is done)
#   ./opencode-build.sh model     # pull/update the Gemma 4 model only
#   ./opencode-build.sh status    # print environment status
# =============================================================================
set -euo pipefail

# ─── Colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${BLUE}ℹ  $*${NC}"; }
success() { echo -e "${GREEN}✓  $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
error()   { echo -e "${RED}✗  $*${NC}" >&2; }
header()  { echo -e "\n${CYAN}━━━  $*  ━━━${NC}"; }

# ─── Configuration ──────────────────────────────────────────────────────────

# Gemma 4 27B with Q4_K_M quantisation uses ~16 GB of unified RAM.
# On a 36 GB Mac Studio this leaves ~20 GB for macOS + Julia + browser.
# Change to "gemma4:12b" to halve the memory footprint (~8 GB).
MODEL="gemma4:27b"

# Ollama server URL (default)
OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"

# Context window for a large Julia codebase (32 k tokens is a good default;
# Gemma 4 supports up to 128 k but 32 k keeps inference fast).
CONTEXT_WINDOW=32768

# Julia thread count — "auto" maps to the number of performance cores.
JULIA_THREADS="${JULIA_THREADS:-auto}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_CONFIG="$PROJECT_DIR/opencode.json"

# ─── Helpers ────────────────────────────────────────────────────────────────

require_macos_apple_silicon() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        error "This script is designed for macOS. Detected: $(uname -s)"
        exit 1
    fi
    if [[ "$(uname -m)" != "arm64" ]]; then
        warn "Not running on Apple Silicon (arm64). Performance will be lower."
        warn "Ollama GPU acceleration requires Apple Silicon."
    fi
}

check_or_install_brew() {
    if command -v brew &>/dev/null; then
        success "Homebrew $(brew --version | head -1 | awk '{print $2}')"
        return
    fi
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
    success "Homebrew installed"
}

check_or_install_ollama() {
    if command -v ollama &>/dev/null; then
        success "Ollama $(ollama --version 2>/dev/null | head -1)"
        return
    fi
    info "Installing Ollama via Homebrew..."
    brew install ollama
    success "Ollama installed"
}

start_ollama_server() {
    # Check if Ollama is already running
    if curl -sf "$OLLAMA_HOST/api/tags" &>/dev/null; then
        success "Ollama server already running at $OLLAMA_HOST"
        return
    fi

    info "Starting Ollama server (background)..."

    # Apple Silicon optimisations
    export OLLAMA_NUM_PARALLEL=1         # one request at a time — frees full RAM for the model
    export OLLAMA_MAX_LOADED_MODELS=1    # keep only one model in VRAM
    export OLLAMA_FLASH_ATTENTION=1      # Metal-accelerated flash attention on Apple Silicon
    export OLLAMA_KV_CACHE_TYPE=q8_0     # quantised KV cache to save RAM

    ollama serve &>/tmp/ollama-rhsim.log &
    OLLAMA_PID=$!

    # Wait until the server is ready (up to 20 s)
    for i in $(seq 1 20); do
        if curl -sf "$OLLAMA_HOST/api/tags" &>/dev/null; then
            success "Ollama server started (PID $OLLAMA_PID)"
            return
        fi
        sleep 1
    done
    error "Ollama server did not start within 20 s. Check /tmp/ollama-rhsim.log"
    exit 1
}

pull_model() {
    header "Gemma 4 model"
    info "Checking for model: $MODEL"

    # Check if already pulled
    if ollama list 2>/dev/null | grep -q "^${MODEL}"; then
        success "Model $MODEL already available locally"
        return
    fi

    info "Pulling $MODEL (~16 GB download). This may take several minutes..."
    info "On a fast connection (~500 Mbps) expect ~5–10 min."
    ollama pull "$MODEL"
    success "Model $MODEL ready"
}

check_or_install_opencode() {
    if command -v opencode &>/dev/null; then
        success "opencode $(opencode --version 2>/dev/null || echo '(version unknown)')"
        return
    fi

    info "Installing opencode..."

    # Prefer Homebrew tap if available; fall back to npm global install
    if brew tap sst/tap &>/dev/null 2>&1 && brew install opencode &>/dev/null 2>&1; then
        success "opencode installed via Homebrew"
    elif command -v npm &>/dev/null; then
        npm install -g opencode-ai
        success "opencode installed via npm"
    else
        error "Cannot install opencode: neither 'brew' (sst/tap) nor 'npm' is available."
        error "Install manually: https://opencode.ai/docs/installation"
        exit 1
    fi
}

check_or_install_julia() {
    if command -v julia &>/dev/null; then
        local ver
        ver=$(julia --version 2>/dev/null | awk '{print $3}')
        success "Julia $ver"
        # Warn if version is below the project requirement (1.11)
        if [[ "$(echo "$ver" | cut -d. -f1-2)" < "1.11" ]]; then
            warn "Project requires Julia ≥ 1.11. Please upgrade."
        fi
        return
    fi

    info "Installing Julia 1.11 LTS via Homebrew..."
    brew install julia
    success "Julia installed"
}

instantiate_julia_project() {
    header "Julia project"
    info "Instantiating packages (this runs once; expect 2–5 min first time)..."
    cd "$PROJECT_DIR"

    # Use --compiled-modules=no because the sandbox disk may be full.
    # On your Mac Studio this flag is optional but kept for parity with CI.
    julia --project=. --threads="$JULIA_THREADS" -e '
        using Pkg
        Pkg.instantiate()
        println("✓ Packages instantiated")
    ' || warn "Package instantiation encountered issues. Run 'make deps' to retry."

    success "Julia environment ready"
}

write_opencode_config() {
    # Only write if the file does not exist yet so we do not overwrite
    # manual customisations.
    if [[ -f "$OPENCODE_CONFIG" ]]; then
        success "opencode.json already exists — skipping write"
        return
    fi

    info "Writing $OPENCODE_CONFIG..."
    cat > "$OPENCODE_CONFIG" << EOF
{
  "\$schema": "https://opencode.ai/config.schema.json",

  "model": "ollama/${MODEL}",

  "providers": {
    "ollama": {
      "name": "Ollama (local)",
      "baseURL": "${OLLAMA_HOST}/v1"
    }
  },

  "autoshare": false,
  "theme": "opencode",

  "instructions": [
    "You are working on the **Rural Hospital Economics Platform** (ruralpeds/Hospital-economics).",
    "Stack: Julia 1.11, Genie/Stipple web framework, SearchLight ORM (PostgreSQL), JuMP/HiGHS optimisation, ABM/DES/MC simulation.",
    "Two internal packages: packages/FinanceEngine (CFO analytics) and packages/RuralCore (auth, audit, config).",
    "All tests run with: julia --compiled-modules=no --startup-file=no --project=. test/TESTFILE.jl",
    "Build: make deps (install), make run (dev server on :8000), make test (test suite), make lint (Aqua.jl).",
    "CSS uses CSS custom properties (var(--color-*), var(--space-*)) — never raw hex codes.",
    "Use html_escape() for user strings in HTML; use _safe_href() for href attributes.",
    "New analytics modules follow the four-artifact rule: (1) src/ function, (2) Genie route+controller, (3) Stipple view, (4) tests.",
    "P0 open gaps: MIPS/VBP/HRRP scoring (E-06), treasury model (A-09), service-line portfolio (B-03), DEA (C-01), board PDF packet (F-01), HCRIS CLI importer (F-06), real-options valuation (A-06).",
    "See MBA_GAP_ANALYSIS_2026.md for the full prioritised gap list and architecture spec."
  ],

  "keybindings": {
    "leader": "ctrl+x"
  }
}
EOF
    success "opencode.json written"
}

print_status() {
    header "Environment status"
    echo ""
    printf "  %-30s %s\n" "macOS / arch:" "$(sw_vers -productVersion 2>/dev/null || echo 'n/a') / $(uname -m)"
    printf "  %-30s %s\n" "Memory (physical):" "$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f GB", $1/1024/1024/1024}' || echo 'n/a')"
    printf "  %-30s %s\n" "Homebrew:" "$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo 'not found')"
    printf "  %-30s %s\n" "Ollama:" "$(ollama --version 2>/dev/null | head -1 || echo 'not found')"
    printf "  %-30s %s\n" "opencode:" "$(opencode --version 2>/dev/null || echo 'not found')"
    printf "  %-30s %s\n" "Julia:" "$(julia --version 2>/dev/null | awk '{print $3}' || echo 'not found')"
    printf "  %-30s %s\n" "Target model:" "$MODEL"
    printf "  %-30s %s\n" "Ollama host:" "$OLLAMA_HOST"
    printf "  %-30s %s\n" "Context window (tokens):" "$CONTEXT_WINDOW"
    printf "  %-30s %s\n" "Project dir:" "$PROJECT_DIR"

    echo ""
    if ollama list 2>/dev/null | grep -q "^${MODEL}"; then
        success "Model $MODEL is available locally"
    else
        warn "Model $MODEL is NOT yet pulled. Run: ./opencode-build.sh model"
    fi
    echo ""
}

do_setup() {
    header "Prerequisites"
    require_macos_apple_silicon
    check_or_install_brew
    check_or_install_ollama
    check_or_install_opencode
    check_or_install_julia

    header "Ollama server"
    start_ollama_server

    pull_model

    header "Project configuration"
    write_opencode_config
    instantiate_julia_project
}

do_launch() {
    header "Launching opencode"
    start_ollama_server

    # Pre-warm the model so the first inference has no cold-start delay.
    info "Pre-warming $MODEL (sends an empty generation request)..."
    curl -sf "$OLLAMA_HOST/api/generate" \
        -d "{\"model\":\"${MODEL}\",\"prompt\":\"\",\"stream\":false}" \
        -o /dev/null || true
    success "Model warmed"

    info "Starting opencode in $PROJECT_DIR ..."
    echo ""
    cd "$PROJECT_DIR"
    exec opencode
}

# ─── Entry point ────────────────────────────────────────────────────────────

COMMAND="${1:-all}"

case "$COMMAND" in
    setup)
        do_setup
        echo ""
        success "Setup complete. Run './opencode-build.sh launch' to start opencode."
        ;;
    launch)
        do_launch
        ;;
    model)
        require_macos_apple_silicon
        check_or_install_ollama
        start_ollama_server
        pull_model
        ;;
    status)
        print_status
        ;;
    all|"")
        do_setup
        echo ""
        print_status
        do_launch
        ;;
    *)
        echo "Usage: ./opencode-build.sh [setup|launch|model|status|all]"
        echo ""
        echo "  (no argument)  Full setup then launch opencode"
        echo "  setup          Install all prerequisites, pull model, write config"
        echo "  launch         Start Ollama + opencode (assumes setup is done)"
        echo "  model          Pull / update the Gemma 4 model only"
        echo "  status         Print environment status"
        exit 1
        ;;
esac
