#!/usr/bin/env bash
# 拉取 dl-cache Release 缓存 → 校验 → 解压进 DL_DIR（供离线构建）。
#
# 用法：
#   scripts/pull-dl-cache.sh [目标 downloads 目录]
#
# 环境变量：
#   EMBEDAI_REPO        默认 zishuowang696/embedai
#   EMBEDAI_CACHE_TAG   默认 dl-cache
#   EMBEDAI_STAGE       暂存目录，默认 ~/.cache/embedai-dl-cache（需与目标同一文件系统）
#   EMBEDAI_MIRRORS     空格分隔的镜像前缀，**必须支持 HTTP Range**；默认 ghproxy.net + ghfast.top
#   EMBEDAI_JOBS        并发文件数（默认 4）
#   EMBEDAI_CONN        每文件连接数/分段数（默认 8）
#
# 依赖：gh（取资产清单）、tar、sha256sum、aria2c（推荐；缺失则回退 curl）
#
# 注意：
#   - 镜像必须支持 Range（206）。不支持 Range 的代理会让分段下载写错位、损坏分卷
#     （如 gh-proxy.com 返回 200 全量 → 禁用）。
#   - 不要用多个进程并发写同一文件；统一交给 aria2（或 curl）单一写者。
set -euo pipefail

REPO="${EMBEDAI_REPO:-zishuowang696/embedai}"
TAG="${EMBEDAI_CACHE_TAG:-dl-cache}"
DEST="${1:-$HOME/tegra/tegra-demo-distro/build/downloads}"
STAGE="${EMBEDAI_STAGE:-$HOME/.cache/embedai-dl-cache}"
MIRRORS="${EMBEDAI_MIRRORS:-https://ghproxy.net https://ghfast.top}"
JOBS="${EMBEDAI_JOBS:-4}"
CONN="${EMBEDAI_CONN:-8}"

command -v gh >/dev/null 2>&1 || { echo "需要 gh CLI（gh auth login）"; exit 1; }
mkdir -p "$STAGE" "$DEST"
cd "$STAGE"

echo "[1/4] 取资产清单 ($REPO / $TAG)"
gh api "repos/$REPO/releases/tags/$TAG" \
  --jq '.assets[] | [.name, .browser_download_url] | @tsv' > assets.tsv
[ -s assets.tsv ] || { echo "没有资产，检查 tag 是否正确"; exit 1; }

echo "[2/4] 下载（镜像：$MIRRORS）"
if command -v aria2c >/dev/null 2>&1; then
  : > dl.aria2
  while IFS=$'\t' read -r name url; do
    for m in $MIRRORS; do printf '%s/%s\n' "$m" "$url"; done
    printf '  out=%s\n' "$name"
  done < assets.tsv
  echo "  使用 aria2c（多源分段，可续传）"
  aria2c -c -j "$JOBS" -x "$CONN" -s "$CONN" -k 1M --file-allocation=none \
    --summary-interval=30 --console-log-level=warn -d "$STAGE" -i dl.aria2
else
  first="$(printf '%s\n' $MIRRORS | head -1)"
  : > dl.curlconf
  while IFS=$'\t' read -r name url; do
    printf 'url = "%s/%s"\noutput = "%s"\n' "$first" "$url" "$name"
  done < assets.tsv > dl.curlconf
  echo "  使用 curl -Z（单镜像；aria2 缺失）"
  curl -Z --parallel-max "$JOBS" --retry 5 --retry-delay 5 -L -C - --config dl.curlconf
fi

echo "[3/4] 校验 SHA256（不通过会中止）"
sha256sum -c SHA256SUMS

echo "[4/4] 解压到 $DEST"
cat dl-cache.part-?? | tar -xf - -C "$DEST"

echo "完成 -> $DEST"
echo "离线构建： cd ~/tegra-kas && BB_NO_NETWORK=1 kas build kas.yml"
