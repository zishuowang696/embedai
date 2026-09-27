# 下载缓存：把 GitHub 上的 20GB 源码缓存拉到本地离线构建

Yocto 首次构建的瓶颈几乎总是**下载**（几十 GB）。本流程把"下载"搬到 GitHub 云端（不受墙影响），再把缓存拉回本地做**离线构建**。

## 流水线

```
[GitHub Actions]  .github/workflows/fetch-cache.yml
   bitbake -k --runall=fetch embedai-image        # 只拉源码，不编译
   tar downloads/ | split -b 1900M → dl-cache.part-xx + SHA256SUMS
   上传到 Release：dl-cache（<2GiB/文件，总量不限）
        ↓
[本地]  scripts/pull-dl-cache.sh
   多镜像 aria2 分段下载 → sha256sum -c → 解压进 DL_DIR
        ↓
[本地]  BB_NO_NETWORK=1 kas build kas.yml          # 离线构建
```

## 为什么用 Release 存缓存

| 资源 | 限制 | 结论 |
| --- | --- | --- |
| **Release assets** | 单文件 <2GiB、≤1000 资产、**总量/带宽不限** | ✅ 适合 20GB 缓存 |
| Actions cache | 每仓库 10GB | ❌ |
| Actions artifacts | Free 500MB 且会过期 | ❌ |

## 用法

```bash
# 1) 拉缓存（默认镜像 ghproxy.net + ghfast.top）
scripts/pull-dl-cache.sh

#    自定义镜像 / 目标目录
EMBEDAI_MIRRORS="https://ghproxy.net" scripts/pull-dl-cache.sh /path/to/downloads

# 2) 离线构建
BB_NO_NETWORK=1 kas build kas.yml

# 换镜像前先测速
scripts/speedtest-github.sh
```

脚本行为：取资产清单 → 多源 aria2 分段下载（断点续传）→ `sha256sum -c` 校验（不通过即中止）→ 解压进 `DL_DIR`。`aria2c` 缺失时回退 `curl -Z`。

## 踩坑与要点（真实教训）

1. **镜像必须支持 HTTP Range（206）**。不支持 Range 的代理（如 `gh-proxy.com` 返回 200 全量）会让 aria2 分段下载**写错位**，之后 `sha256sum -c` 大面积失败。默认镜像已避开。
2. **不要多进程并发写同一文件**（curl + aria2 同时写会损坏分卷）。统一交给**单一写者**。
3. **必须校验** `sha256sum -c SHA256SUMS`；不通过就删除坏卷重下（`pull-dl-cache.sh` 会自动校验）。
4. **单连接会被限速**；多连接/多镜像能填满，但**总带宽到顶就封顶**（本机实测 ~6MB/s）。
5. **下载与编译分离**：`--runall=fetch` 只拉源码，可中断、可重跑。
6. **首次构建慢是"工具链自举"**（CPU 密集），不是网络；**sstate 复用**可大幅加速后续（CI 里 qemu 构建已复用真机 sstate）。

## 实测（2026-09）

- 云端 fetch：**20.6GB / 11 分卷**，约 40 分钟。
- 本地拉取：多源 ~6MB/s；`sha256sum -c` **通过**；解压后 `DL_DIR` ~42GB（含旧缓存合并）。
- 离线构建：`BB_NO_NETWORK=1 kas build kas.yml` 正常推进（`task 1703/8043 …`）。

## 相关文档与脚本

- `scripts/pull-dl-cache.sh` — 拉取 + 校验 + 解压（本流程）
- `scripts/speedtest-github.sh` — 镜像测速
- `.github/workflows/fetch-cache.yml` — 云端 fetch + 分卷发布到 Release
- `docs/07-local-build.md` — 本地构建（国内网络优化）
- `docs/10-github-mirrors.md` — 镜像测速与代理
- 文章：《GitHub 下载加速与 CI 缓存》
