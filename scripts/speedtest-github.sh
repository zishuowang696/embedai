#!/bin/sh
# 测 GitHub 下载镜像速度：对同一个 URL 各取 N MB，输出实际 MB/s。
# 用法：
#   scripts/speedtest-github.sh [URL] [MB]
# 默认测 embedai 的 dl-cache 分卷，取 20MB。
# 自定义镜像列表：
#   MIRRORS="https://ghproxy.net https://gh-proxy.com" scripts/speedtest-github.sh
set -u

URL="${1:-https://github.com/zishuowang696/embedai/releases/download/dl-cache/dl-cache.part-aa}"
MB="${2:-20}"
END=$(( MB * 1024 * 1024 - 1 ))
MIRRORS="${MIRRORS:-https://ghproxy.net https://gh-proxy.com https://ghfast.top}"

printf '%-30s %12s %8s %8s\n' SOURCE BYTES TIME MB/s
printf '%-30s %12s %8s %8s\n' ------------------------------ ------------ -------- --------

test_url() {
  name="$1"
  prefix="$2"
  if [ -n "$prefix" ]; then url="$prefix/$URL"; else url="$URL"; fi
  out=$(timeout 45 curl -s -L -r "0-$END" -o /dev/null --max-time 30 \
        -w '%{size_download} %{time_total} %{speed_download}' "$url" 2>/dev/null || true)
  bytes=$(printf '%s' "$out" | awk '{print $1+0}')
  t=$(printf '%s' "$out" | awk '{print $2+0}')
  sp=$(printf '%s' "$out" | awk '{print $3+0}')
  mbs=$(awk -v s="$sp" 'BEGIN{printf "%.2f", s/1048576}')
  printf '%-30s %12s %8s %8s\n' "$name" "$bytes" "$t" "$mbs"
}

test_url "direct-github" ""
for m in $MIRRORS; do
  test_url "$m" "$m"
done

echo
echo "提示：单连接测速；多连接并行（6 路）总速度约为单连接的数倍。"
