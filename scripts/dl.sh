#!/usr/bin/env bash
# 顺手下载器：不用记 aria2c。自动给 GitHub URL 加镜像 + 多线程 + 断点续传。
#
# 用法：
#   scripts/dl.sh <url> [更多 url ...]
#   scripts/dl.sh https://github.com/.../a.zst https://github.com/.../b.zst
#
# 环境变量：EMBEDAI_MIRRORS（默认 ghproxy.net + ghfast.top）
set -euo pipefail

MIRRORS="${EMBEDAI_MIRRORS:-https://ghproxy.net https://ghfast.top}"
[ $# -ge 1 ] || { echo "用法: $0 <url> [...]"; exit 1; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for u in "$@"; do
  case "$u" in
    *github.com/*)
      first=1
      for m in $MIRRORS; do
        if [ "$first" = 1 ]; then printf '%s/%s' "${m%/}" "$u"; first=0; else printf '\t%s/%s' "${m%/}" "$u"; fi
      done
      printf '\n'
      ;;
    *) printf '%s\n' "$u" ;;
  esac
done > "$tmp"

if command -v aria2c >/dev/null 2>&1; then
  aria2c -c -j4 -x8 -s8 -k1M --file-allocation=none \
    --summary-interval=30 --console-log-level=warn -i "$tmp"
else
  echo "！未装 aria2，单连接会慢： sudo apt install -y aria2   （或用 winget install aria2.aria2）"
  while IFS= read -r line; do
    url="${line%%$'\t'*}"          # 多镜像时取第一个
    curl -L -C - --retry 5 -O "$url"
  done < "$tmp"
fi
