# GitHub 下载加速与镜像测速

国内直连 `github.com/.../releases/download/...` 经常超时或很慢。常见做法是用**第三方加速前缀**代理 GitHub 的下载链接。

> 本文档只针对"下载文件"。代码托管、Actions、Release 存储仍由 GitHub 提供；`curl` 只是传输工具，能替代 `gh` 的下载/GET，但替代不了 GitHub 平台本身。

## 实测（2026-09-14，本机，单连接取 20MB）

| 源（前缀） | 实测速度 | 结论 |
| --- | --- | --- |
| 直连 `https://github.com` | 超时 / 0 | 不稳定，经常连不上 |
| `https://ghproxy.net` | **1.19 MB/s** | ✅ 可用，最快 |
| `https://gh-proxy.com` | 0.69 MB/s | ✅ 可用 |
| `https://ghfast.top` | 0.22 MB/s | 可用但慢 |
| `https://gh-proxy.net` | 失败（195B） | ❌ |
| `https://gitproxy.click` | 失败（195B） | ❌ |
| `https://gh.api.99988866.xyz` | 失败 | ❌ |
| `https://hub.gitmirror.com` | 失败 | ❌ |

说明：
- 上表是**单连接**速度；多连接并行（6 路）可叠加到约 **6–7 MB/s**。
- 代理服务质量随时间变化，测速仅代表当天本机结果。

## 用法

**前缀拼接**（把原 URL 直接接到代理后面）：
```bash
curl -L -O "https://ghproxy.net/https://github.com/<owner>/<repo>/releases/download/<tag>/<file>"
```

**断点续传**：
```bash
curl -L -C - -O "https://ghproxy.net/https://github.com/..."
```

**多文件并行**（curl ≥ 7.66）：
```bash
# dl.curlconf 里每个资产两行：
#   url = "https://ghproxy.net/https://github.com/..."
#   output = "文件名"
curl -Z --parallel-max 6 -L -C - --config dl.curlconf
```

## 下载本项目的构建缓存

`scripts/pull-dl-cache.sh` 已支持镜像前缀与断点续传：

```bash
# 直连（或已能访问 GitHub）
scripts/pull-dl-cache.sh

# 走国内加速
EMBEDAI_MIRROR=https://ghproxy.net scripts/pull-dl-cache.sh

# 指定解压目标
EMBEDAI_MIRROR=https://ghproxy.net scripts/pull-dl-cache.sh /path/to/downloads
```

脚本会：取资产清单 → 并行下载（断点续传）→ `sha256sum -c` 校验 → 解压进 DL_DIR。

## 注意事项

- 第三方代理**不稳定、可能随时失效**，且会看到你的下载 URL；**不要用于敏感/私有内容**。
- 下载后**务必校验 SHA256**（脚本已内置）。
- 对 **Yocto 源码**，优先配置 bitbake 的镜像（如 kernel.org 用 USTC、huggingface 用 hf-mirror），比逐个代理 GitHub 更稳、更快。
- GitHub 公开仓库的 release 资产用 `curl` 即可（无需登录）；需鉴权的操作（建 Release、触发 workflow）仍建议用 `gh` + token。
