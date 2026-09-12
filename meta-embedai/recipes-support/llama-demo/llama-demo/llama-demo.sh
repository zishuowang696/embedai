#!/bin/bash
# EmbedAI llama.cpp demo CLI
# Usage:
#   llama-demo              Interactive menu
#   llama-demo chat         Interactive chat session
#   llama-demo server       Start HTTP API server (port 8080)
#   llama-demo download     Download a small quantized model
#   llama-demo bench        Run a quick performance benchmark
#   llama-demo prompt TEXT  One-shot prompt (no interaction)

set -e

# ── Defaults ──────────────────────────────────────────────────────────
MODEL_DIR="/var/lib/llama/models"
DEFAULT_MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf"
LLAMA_CLI="llama-cli"
LLAMA_SERVER="llama-server"

# ── Colors ────────────────────────────────────────────────────────────
BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

info()  { printf "${GREEN}%s${NC}\n" "$*"; }
warn()  { printf "${YELLOW}%s${NC}\n" "$*"; }
err()   { printf "${RED}%s${NC}\n" "$*" >&2; }
header(){ printf "\n${BOLD}${CYAN}━━━ %s ━━━${NC}\n" "$*"; }

# ── Helpers ───────────────────────────────────────────────────────────

find_model() {
    for d in "$MODEL_DIR" /home/root/models /root /home; do
        if [ -d "$d" ]; then
            found=$(find "$d" -maxdepth 2 -name '*.gguf' -type f 2>/dev/null | head -n 1)
            if [ -n "$found" ]; then
                echo "$found"
                return 0
            fi
        fi
    done
    return 1
}

require_model() {
    MODEL_FILE=$(find_model)
    if [ -z "$MODEL_FILE" ]; then
        err "No GGUF model found."
        err "Run:  llama-demo download"
        return 1
    fi
    info "Using model: $MODEL_FILE"
}

banner() {
    cat <<'EOF'
  ╭──────────────────────────────╮
  │  EmbedAI — Edge LLM Gateway  │
  │  Jetson Orin Nano Super      │
  ╰──────────────────────────────╯
EOF
}

# ── Commands ──────────────────────────────────────────────────────────

cmd_download() {
    header "Download Model"
    mkdir -p "$MODEL_DIR"
    url="${1:-$DEFAULT_MODEL_URL}"
    filename="${url##*/}"
    outpath="$MODEL_DIR/$filename"

    if [ -f "$outpath" ]; then
        info "Model already exists: $outpath ($(du -h "$outpath" | cut -f1))"
        return 0
    fi
    if ! command -v wget >/dev/null 2>&1; then
        err "wget not found — cannot download model"
        return 1
    fi
    info "Downloading: $url"
    wget --progress=dot:giga -O "$outpath" "$url"
    info "Saved to: $outpath ($(du -h "$outpath" | cut -f1))"
}

cmd_chat() {
    require_model || return 1
    header "Chat Mode (Ctrl+D to exit)"
    exec $LLAMA_CLI -m "$MODEL_FILE" -c 4096 -ngl 0 --temp 0.7 --repeat-penalty 1.1 --color -i
}

cmd_server() {
    require_model || return 1
    header "Starting llama-server on port 8080"
    info "Access: http://<device-ip>:8080"
    info "API:    curl http://<device-ip>:8080/v1/chat/completions"
    exec $LLAMA_SERVER -m "$MODEL_FILE" -c 4096 -ngl 0 --host 0.0.0.0 --port 8080
}

cmd_bench() {
    require_model || return 1
    header "Benchmark"
    echo "  Cores: $(nproc)"
    echo "  RAM:   $(free -h | awk '/Mem:/{print $2}')"
    info "Generation speed (128 tokens)..."
    $LLAMA_CLI -m "$MODEL_FILE" -c 4096 -ngl 0 -p "Hello" -n 128 2>&1 | tail -5
}

cmd_prompt() {
    require_model || return 1
    [ -z "$*" ] && { err "Usage: llama-demo prompt <text>"; return 1; }
    exec $LLAMA_CLI -m "$MODEL_FILE" -c 4096 -ngl 0 --temp 0.7 -p "$*" -n 256
}

cmd_menu() {
    while true; do
        clear
        banner
        echo
        model_path=$(find_model || true)
        if [ -n "$model_path" ]; then
            printf "  ${GREEN}✓${NC} Model: ${BOLD}%s${NC}  (%s)\n" "$(basename "$model_path")" "$(du -h "$model_path" 2>/dev/null | cut -f1)"
        else
            printf "  ${YELLOW}✗${NC} No model found — run ${BOLD}download${NC} first\n"
        fi
        echo
        echo "  1) Chat        — Interactive terminal chat"
        echo "  2) Server      — HTTP API on port 8080"
        echo "  3) Download    — Get a small quantized model"
        echo "  4) Benchmark   — Measure inference speed"
        echo "  q) Quit"
        echo
        printf "Choice [1-4,q]: "
        read -r choice
        echo
        case "$choice" in
            1) cmd_chat ;;
            2) cmd_server ;;
            3) cmd_download ;;
            4) cmd_bench ;;
            q|Q) exit 0 ;;
            *) warn "Invalid choice" ;;
        esac
        echo
        printf "Press Enter to return to menu..."; read -r _
    done
}

# ── Main ──────────────────────────────────────────────────────────────

check_deps() {
    missing=0
    for bin in $LLAMA_CLI $LLAMA_SERVER; do
        command -v "$bin" >/dev/null 2>&1 || { err "Missing: $bin — install llama-cpp package"; missing=1; }
    done
    return $missing
}

case "${1:-menu}" in
    chat)     shift; check_deps && cmd_chat "$@" ;;
    server)   shift; check_deps && cmd_server "$@" ;;
    download) shift; check_deps && cmd_download "$@" ;;
    bench)    shift; check_deps && cmd_bench "$@" ;;
    prompt)   shift; check_deps && cmd_prompt "$@" ;;
    menu|"")  check_deps && cmd_menu ;;
    *)        echo "Usage: llama-demo {chat|server|download|bench|prompt}" >&2; exit 1 ;;
esac
