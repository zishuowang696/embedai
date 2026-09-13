#!/bin/sh
# 拉取 GitHub 上的 DL_DIR 缓存（Release: dl-cache），解压进本地 downloads 目录。
#
# 用法：
#   scripts/pull-dl-cache.sh [目标 downloads 目录]
# 默认目标：~/tegra/tegra-demo-distro/build/downloads
#
# 依赖：gh（已登录）、tar、sha256sum
set -e

REPO="${EMBEDAI_REPO:-zishuowang696/embedai}"
TAG="${EMBEDAI_CACHE_TAG:-dl-cache}"
DEST="${1:-$HOME/tegra/tegra-demo-distro/build/downloads}"

command -v gh >/dev/null 2>&1 || { echo "需要 gh CLI（gh auth login）"; exit 1; }
mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "下载 $REPO 的 $TAG 到 $TMP ..."
gh release download "$TAG" -R "$REPO" -D "$TMP"

echo "校验分卷 ..."
( cd "$TMP" && sha256sum -c SHA256SUMS )

echo "解压到 $DEST ..."
cat "$TMP"/dl-cache.part-* | tar -xf - -C "$DEST"

echo "完成 -> $DEST"
echo "之后可离线构建：  BB_NO_NETWORK=\"1\" kas build kas.yml"
