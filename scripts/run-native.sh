#!/usr/bin/env bash
# 在 Linux（x86_64 / arm64）上**原生**跑 llama.cpp + Qwen2.5-0.5B(Q2_K)，
# 验证"模型 / 量化 / 速度"。用的是与 embedai 镜像**同一个模型**（同 sha256），
# 但**不经过 QEMU**，所以是真实速度（不是模拟）。
#
# 用法：
#   scripts/run-native.sh
#   PROMPT="写一个 hello world" NTOKENS=128 scripts/run-native.sh
# 环境变量：
#   MODEL_URL MODEL_SHA PROMPT NTOKENS THREADS
#   MODEL_DIR(./models) LLAMA_DIR(./llama.cpp) BUILD_DIR(./llama.cpp/build) SKIP_BUILD
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-./models}"
MODEL_FILE="$MODEL_DIR/qwen2.5-0.5b-instruct-q2_k.gguf"
MODEL_URL="${MODEL_URL:-https://hf-mirror.com/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf}"
MODEL_SHA="${MODEL_SHA:-9ee36184e616dfc76df4f5dd66f908dbde6979524ae36e6cefb67f532f798cb8}"
LLAMA_DIR="${LLAMA_DIR:-./llama.cpp}"
BUILD_DIR="${BUILD_DIR:-$LLAMA_DIR/build}"
PROMPT="${PROMPT:-用一句话介绍你自己}"
NTOKENS="${NTOKENS:-64}"
THREADS="${THREADS:-$(nproc 2>/dev/null || echo 4)}"

need() { command -v "$1" >/dev/null 2>&1; }

echo "== 检查依赖 =="
missing=()
for c in git cmake curl sha256sum; do need "$c" || missing+=("$c"); done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "缺少: ${missing[*]}"
  echo "Debian/Ubuntu: sudo apt install -y build-essential cmake git curl coreutils"
  exit 1
fi

echo "== 模型 =="
mkdir -p "$MODEL_DIR"
if [ ! -f "$MODEL_FILE" ]; then
  echo "下载: $MODEL_URL"
  curl -L --fail -C - -o "$MODEL_FILE" "$MODEL_URL"
else
  echo "已存在: $MODEL_FILE"
fi
echo "校验 sha256..."
sum=$(sha256sum "$MODEL_FILE" | awk '{print $1}')
[ "$sum" = "$MODEL_SHA" ] || { echo "sha256 不匹配！实际=$sum 期望=$MODEL_SHA"; exit 1; }
echo "sha256 OK"

echo "== llama.cpp =="
BIN="$BUILD_DIR/bin/llama-cli"
if [ ! -x "$BIN" ] && [ "${SKIP_BUILD:-0}" != "1" ]; then
  [ -d "$LLAMA_DIR" ] || git clone --depth 1 https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
  cmake -B "$BUILD_DIR" -S "$LLAMA_DIR" -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_TESTS=OFF
  cmake --build "$BUILD_DIR" --target llama-cli -j"$THREADS"
fi
[ -x "$BIN" ] || { echo "未找到 $BIN（可设 SKIP_BUILD=1 并自备 BUILD_DIR）"; exit 1; }

echo "== 运行（原生速度，非 QEMU）=="
"$BIN" -m "$MODEL_FILE" -p "$PROMPT" -n "$NTOKENS" -t "$THREADS"
