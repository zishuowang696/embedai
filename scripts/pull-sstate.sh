#!/usr/bin/env bash
# 拉取 CI 持久化的 sstate（Release: sstate-jetson / sstate-qemu）→ 解压进本地 build/sstate-cache。
#
# 目的：本地增量构建复用 CI 已编译的任务（改一个 recipe = 只重编它，其余命中 sstate）。
#
# 资产命名（版本化）：
#   sstate-<ID>.part-aa, part-ab, ...   ID = <UTC时间>-<runid>
#   sstate-<ID>.SHA256SUMS
#   LATEST                              内容为当前最新完整集合的 ID
# 兼容旧命名：sstate.part-*(无 LATEST 时回退)
#
# 用法：
#   scripts/pull-sstate.sh [machine|qemu]
#     machine（默认）: 拉 sstate-jetson（jetson-orin-nano-devkit-nvme）
#     qemu            : 拉 sstate-qemu（qemuarm64）
#
# 环境变量：
#   EMBEDAI_REPO       默认 zishuowang696/embedai
#   EMBEDAI_BUILD_DIR  本地 build 目录，默认 <repo>/build
#   EMBEDAI_STAGE      暂存目录，默认 ~/.cache/embedai-sstate
#   EMBEDAI_MIRRORS    空格分隔镜像前缀，**必须支持 HTTP Range**；默认 ghproxy.net + ghfast.top
#   EMBEDAI_JOBS       并发文件数（默认 4）
#   EMBEDAI_CONN       每文件分段数（默认 8）
#
# 依赖：gh、tar、sha256sum、aria2c（推荐，缺失回退 curl）
set -euo pipefail

WHICH="${1:-machine}"
case "$WHICH" in
  machine|jetson) TAG="${EMBEDAI_SSTATE_TAG:-sstate-jetson}" ;;
  qemu)           TAG="${EMBEDAI_SSTATE_TAG:-sstate-qemu}" ;;
  *) echo "用法: $0 [machine|qemu]"; exit 1 ;;
esac

REPO="${EMBEDAI_REPO:-zishuowang696/embedai}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${EMBEDAI_BUILD_DIR:-$REPO_DIR/build}"
STAGE="${EMBEDAI_STAGE:-$HOME/.cache/embedai-sstate}"
MIRRORS="${EMBEDAI_MIRRORS:-https://ghproxy.net https://ghfast.top}"
JOBS="${EMBEDAI_JOBS:-4}"
CONN="${EMBEDAI_CONN:-8}"

command -v gh >/dev/null 2>&1 || { echo "需要 gh CLI（gh auth login）"; exit 1; }
mkdir -p "$STAGE" "$DEST"
cd "$STAGE"

echo "[1/4] 取资产清单 ($REPO / $TAG)"
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Release '${TAG}' 不存在（CI 还没产出 sstate）。先让 CI 跑完一轮再看。"
  exit 1
fi
gh api "repos/$REPO/releases/tags/$TAG" \
  --jq '.assets[] | [.name, .browser_download_url] | @tsv' > assets_all.tsv

ID=""
rm -f LATEST
gh release download "$TAG" --repo "$REPO" -D "$STAGE" -p 'LATEST' 2>/dev/null || true
[ -f LATEST ] && ID="$(tr -d '[:space:]' < LATEST)"

if [ -n "$ID" ]; then
  echo "  最新集合: $ID"
  PREFIX="sstate-${ID}"
  GREP_RE="^sstate-${ID}\.(part-|SHA256SUMS)"
else
  echo "  无 LATEST，按旧命名回退"
  PREFIX="sstate"
  GREP_RE="^(sstate\.part-|SHA256SUMS)"
fi
grep -E "$GREP_RE" assets_all.tsv > assets.tsv || true
[ -s assets.tsv ] || { echo "没找到可下载的 sstate 资产"; exit 1; }

echo "[2/4] 下载（镜像：$MIRRORS）"
if command -v aria2c >/dev/null 2>&1; then
  : > dl.aria2
  while IFS=$'\t' read -r name url; do
    first=1
    for m in $MIRRORS; do
      if [ "$first" = 1 ]; then printf '%s/%s' "$m" "$url"; first=0; else printf '\t%s/%s' "$m" "$url"; fi
    done
    printf '\n  out=%s\n' "$name"
  done < assets.tsv > dl.aria2
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

echo "[3/4] 校验"
if [ -n "$ID" ] && [ -f "sstate-${ID}.SHA256SUMS" ]; then
  sha256sum -c "sstate-${ID}.SHA256SUMS"
elif [ -f SHA256SUMS ]; then
  sha256sum -c SHA256SUMS
else
  echo "  无 SHA256SUMS，跳过"
fi

echo "[4/4] 解压到 $DEST（生成 $DEST/sstate-cache）"
if [ -n "$ID" ]; then
  cat sstate-${ID}.part-?? | tar -xf - -C "$DEST"
else
  cat sstate.part-?? | tar -xf - -C "$DEST"
fi

echo "完成 -> $DEST/sstate-cache"
echo "本地增量构建： cd $REPO_DIR && BB_NO_NETWORK=1 kas build kas.yml:local/kas-lowmem.yml"
