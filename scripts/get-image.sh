#!/usr/bin/env bash
# 取 Jetson 镜像 / 刷机包（自动探测机器名与资产，不用记文件名）。
#
# 用法（默认参数已内置，**直接跑即可**）：
#   scripts/get-image.sh                 # 下"刷机包"到当前目录（默认机器/仓库/tag 都已定好）
#   scripts/get-image.sh -I              # 只下独立 rootfs 镜像（若有）
#   scripts/get-image.sh --dry-run       # 只看会下什么
#   scripts/get-image.sh -d ./flash      # 指定目录
#   scripts/get-image.sh <machine>       # 指定机器（默认 jetson-orin-nano-devkit-nvme）
#
# 环境变量：EMBEDAI_REPO（默认 zishuowang696/embedai）、EMBEDAI_TAG（默认 image-latest）、EMBEDAI_MACHINE
# 依赖：gh；下载走同目录 gh-download.sh（镜像测速 + aria2 多源 + 校验）
set -euo pipefail

REPO="${EMBEDAI_REPO:-zishuowang696/embedai}"
TAG="${EMBEDAI_TAG:-image-latest}"
DEFAULT_MACHINE="jetson-orin-nano-devkit-nvme"   # 本项目主线，默认用它，免输入
MACHINE="${EMBEDAI_MACHINE:-}"
DEST="."; IMAGE_ONLY=0; DRY=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    -I|--image-only) IMAGE_ONLY=1; shift;;
    -n|--dry-run) DRY=1; shift;;
    -d|--dir) DEST="$2"; shift 2;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    *) MACHINE="$1"; shift;;
  esac
done

command -v gh >/dev/null 2>&1 || { echo "需要 gh CLI"; exit 1; }
names=$(gh api "repos/$REPO/releases/tags/$TAG" --jq '.assets[].name' 2>/dev/null)
[ -n "$names" ] || { echo "取不到 $TAG 的资产（检查 gh 登录/仓库）"; exit 1; }

if [ -z "$MACHINE" ]; then
  # 默认用主线机器；若该 release 里没有，再自动探测
  MACHINE="$DEFAULT_MACHINE"
  printf '%s\n' "$names" | grep -q "^embedai-image-$MACHINE\." || \
    MACHINE=$(printf '%s\n' "$names" | sed -nE 's/^embedai-image-(.+)\.rootfs.*/\1/p' | sort -u | head -1)
fi
[ -n "$MACHINE" ] || { echo "无法探测机器名，请显式给出（如 jetson-orin-nano-devkit-nvme）"; exit 1; }
echo "repo=$REPO  tag=$TAG  machine=$MACHINE$([ "$DRY" = 1 ] && echo '  (dry-run)')"

dl() { # dl <pattern>
  if [ "$DRY" = 1 ]; then
    printf '%s\n' "$names" | grep -E "^$(printf '%s' "$1" | sed 's/[.]/\\./g; s/\*/.*/g')$" | sed 's/^/  将下载: /'
  else
    bash "$DIR/gh-download.sh" "$REPO" "$TAG" --pattern "$1" -d "$DEST"
  fi
}

if [ "$IMAGE_ONLY" = 1 ]; then
  imgs=$(printf '%s\n' "$names" \
    | grep -E "^embedai-image-$MACHINE\.rootfs.*(\.ext4|\.tar)(\.(zst|gz|bz2|xz))?$" \
    | grep -v 'tegraflash-tar' || true)
  if [ -z "$imgs" ]; then
    echo "！当前 release 没有独立 rootfs 镜像（只有刷机包）。可用镜像资产："
    printf '%s\n' "$names" | grep -E "^embedai-image-$MACHINE" | sed 's/^/    /'
    echo "  提示：不带 -I 直接下刷机包；或让 CI 额外发布压缩 rootfs（ext4.zst）。"
    exit 0
  fi
  while IFS= read -r n; do [ -n "$n" ] && dl "$n"; done <<< "$imgs"
else
  dl "embedai-image-$MACHINE.rootfs.tegraflash-tar.zst"
  dl "embedai-image-$MACHINE.rootfs.manifest"
  [ "$DRY" = 0 ] && {
    echo
    echo "刷机（Linux + USB 连接 + 板子进 recovery 模式）："
    echo "  cd $DEST && tar --zstd -xf embedai-image-$MACHINE.rootfs.tegraflash-tar.zst"
    echo "  # 解出后按包内脚本/README 刷入（eMMC/NVMe）"
  }
fi
