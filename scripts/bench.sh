#!/usr/bin/env bash
# bench.sh — 边缘/Jetson 上统一口径的 llama.cpp 推理基准。
# 固定 prompt + 固定 token 数，输出：加载时间、首 token、生成 tok/s、内存/温度/功耗（有则）。
# 目的：让"换模型/换引擎"的实测数据可比，直接进文章。
#
# 用法：
#   scripts/bench.sh <model.gguf> [--ngl N] [--threads N] [--tokens N] [--runs N]
# 例（Jetson 开 GPU）：
#   scripts/bench.sh models/qwen2.5-3b-q4_k_m.gguf --ngl 99
# 环境变量：
#   LLAMA_CLI（默认 llama-cli） PROMPT（默认一句话） PROMPT_TOKENS（默认 32）
set -euo pipefail

MODEL=""; NGL=0; THREADS="$(nproc 2>/dev/null || echo 4)"; NTOKENS=128; RUNS=3
PROMPT="${PROMPT:-用一句话介绍你自己}"
PROMPT_TOKENS="${PROMPT_TOKENS:-32}"
BIN="${LLAMA_CLI:-llama-cli}"

while [ $# -gt 0 ]; do
  case "$1" in
    --ngl) NGL="$2"; shift 2;;
    --threads) THREADS="$2"; shift 2;;
    --tokens) NTOKENS="$2"; shift 2;;
    --runs) RUNS="$2"; shift 2;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) MODEL="$1"; shift;;
  esac
done

[ -n "$MODEL" ] && [ -f "$MODEL" ] || { echo "用法: $0 <model.gguf> [--ngl N] [--threads N] [--tokens N] [--runs N]" >&2; exit 1; }
command -v "$BIN" >/dev/null 2>&1 || { echo "缺 $BIN（装 llama-cpp，或设 LLAMA_CLI）" >&2; exit 1; }

has(){ command -v "$1" >/dev/null 2>&1; }
hw_snap() { # 内存/温度/功耗（Jetson 有 tegrastats；通用 Linux 退化到 meminfo/thermal）
  if has tegrastats; then
    timeout 2 tegrastats --interval 500 2>/dev/null | tail -1
  else
    awk '/MemAvailable/{a=$2}/MemTotal/{t=$2}END{if(t)printf "RAM_used=%.0fMiB RAM_total=%.0fMiB\n",(t-a)/1024,t/1024}' /proc/meminfo
    for z in /sys/class/thermal/thermal_zone0/temp; do [ -r "$z" ] && awk '{printf "temp=%.1fC\n",$1/1000}' "$z"; done
  fi
}

echo "== bench: $(basename "$MODEL") | ngl=$NGL threads=$THREADS n=$NTOKENS runs=$RUNS =="
echo "hw(before): $(hw_snap | tr '\n' ' ')"

gen_ts=""; pp_ts=""; load_ms=""; last_out=""
for r in $(seq 1 "$RUNS"); do
  # 采集 stderr 里的 timings（llama.cpp 的 llama_print_timings 打在 stderr）
  err="$("$BIN" -m "$MODEL" -p "$PROMPT" -n "$NTOKENS" -t "$THREADS" -ngl "$NGL" \
        --no-display-prompt 2>&1 >/dev/null || true)"
  last_out="$err"
  g=$(printf '%s\n' "$err" | grep -oE 'eval time.*tokens per second' | tail -1 | grep -oE '[0-9.]+ tokens per second' | grep -oE '^[0-9.]+' || true)
  p=$(printf '%s\n' "$err" | grep -oE 'prompt eval time.*tokens per second' | tail -1 | grep -oE '[0-9.]+ tokens per second' | grep -oE '^[0-9.]+' || true)
  l=$(printf '%s\n' "$err" | grep -oE 'load time = *[0-9.]+' | tail -1 | grep -oE '[0-9.]+' || true)
  echo "  run $r: gen=${g:-?} tok/s  prompt=${p:-?} tok/s  load=${l:-?} ms"
  # 取最后一次有效值（也可改成取中位数）
  [ -n "${g:-}" ] && gen_ts="$g"
  [ -n "${p:-}" ] && pp_ts="$p"
  [ -n "${l:-}" ] && load_ms="$l"
  sleep 1
done

echo "hw(after):  $(hw_snap | tr '\n' ' ')"

if [ -z "$gen_ts" ]; then
  echo "！没解析到 timings，原始输出尾部如下（可手动看）：" >&2
  printf '%s\n' "$last_out" | tail -20 >&2
  exit 2
fi

# 也输出一行 JSON，方便汇总成文章表格
printf '{"model":"%s","ngl":%s,"threads":%s,"n":%s,"gen_tps":%s,"prompt_tps":%s,"load_ms":%s}\n' \
  "$(basename "$MODEL")" "$NGL" "$THREADS" "$NTOKENS" "${gen_ts:-0}" "${pp_ts:-0}" "${load_ms:-0}"
