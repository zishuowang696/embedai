#!/bin/sh
# 拉取 GitHub Release 上的 DL_DIR 缓存，支持国内加速前缀、断点续传、多连接并行。
#
# 用法：
#   scripts/pull-dl-cache.sh [目标 downloads 目录]
#   EMBEDAI_MIRROR=https://ghproxy.net scripts/pull-dl-cache.sh
#
# 环境变量：
#   EMBEDAI_REPO   默认 zishuowang696/embedai
#   EMBEDAI_CACHE_TAG  默认 dl-cache
#   EMBEDAI_MIRROR 代理前缀，如 https://ghproxy.net（留空=直连）
#   EMBEDAI_STAGE  暂存目录，默认 ~/.cache/embedai-dl-cache（需与目标同一文件系统）
#
# 依赖：gh（取资产清单）、curl、tar、sha256sum
set -e

REPO="${EMBEDAI_REPO:-zishuowang696/embedai}"
TAG="${EMBEDAI_CACHE_TAG:-dl-cache}"
MIRROR="${EMBEDAI_MIRROR:-}"
DEST="${1:-$HOME/tegra/tegra-demo-distro/build/downloads}"
STAGE="${EMBEDAI_STAGE:-$HOME/.cache/embedai-dl-cache}"

command -v gh >/dev/null 2>&1 || { echo "需要 gh CLI（gh auth login）"; exit 1; }
mkdir -p "$STAGE" "$DEST"
cd "$STAGE"

echo "[1/4] 取资产清单 ($REPO / $TAG)"
gh api "repos/$REPO/releases/tags/$TAG" \
  --jq '.assets[] | [.name, .browser_download_url] | @tsv' > assets.tsv
[ -s assets.tsv ] || { echo "没有资产，检查 tag 是否正确"; exit 1; }

echo "[2/4] 生成 curl 配置并并行下载（6 路，断点续传）${MIRROR:+ via $MIRROR}"
: > dl.curlconf
while IFS="$(printf '\t')" read -r name url; do
  if [ -n "$MIRROR" ]; then url="$MIRROR/$url"; fi
  printf 'url = "%s"\noutput = "%s"\n' "$url" "$name" >> dl.curlconf
done < assets.tsv

curl -Z --parallel-max 6 --retry 5 --retry-delay 5 -L -C - --config dl.curlconf

echo "[3/4] 校验 SHA256"
sha256sum -c SHA256SUMS

echo "[4/4] 解压到 $DEST"
cat dl-cache.part-* | tar -xf - -C "$DEST"

echo "完成 -> $DEST"
echo "离线构建：  cd ~/tegra-kas && BB_NO_NETWORK=1 kas build kas.yml"
