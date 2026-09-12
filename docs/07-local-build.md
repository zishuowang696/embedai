# 本地构建（国内网络优化）

首次构建耗时长，**瓶颈通常不是编译，而是拉源码**：GFW 下访问 GitHub / 各类上游下载站经常超时，BitBake 又会在编译过程中零散地 fetch，导致一卡就是一整天。

核心策略：**把「下载」和「编译」拆成两个阶段**——先只 fetch，把源码全部落到本地 `DL_DIR`，再离线编译。

---

## 1. 分阶段：先 fetch，后 build

进入 bitbake 环境（不要直接 build）：

```bash
kas shell kas.yml
```

### 阶段一：只下载源码，不编译

```bash
# 现代 bitbake（kirkstone 及以后）
bitbake --runall=fetch embedai-image

# 旧版 bitbake
bitbake -c fetchall embedai-image
```

- 会遍历 `embedai-image` 依赖树里所有 recipe 的 `fetch` 任务，把源码/压缩包下到 `DL_DIR`。
- **可中断、可重跑**：已下载的不会重复下，网络抖断直接再跑同一条命令即可。
- 遇到个别失败不要停：

```bash
bitbake -k --runall=fetch embedai-image     # -k = keep going
```

> 这一步可能跑几小时到一两天，建议挂着过夜、反复重跑直到不再有新下载。

### 阶段二：离线编译

确认 fetch 完成后，禁止网络再跑构建，能立刻暴露"还缺哪个源"：

```bash
# 在 conf/local.conf 里临时加：
BB_NO_NETWORK = "1"

kas build kas.yml
```

若报某个 recipe 缺源，去掉 `BB_NO_NETWORK` 单独补：

```bash
bitbake -c fetch <recipe>
```

---

## 2. 让下载更稳、更快（conf/local.conf 追加）

```conf
# 官方源码镜像兜底（Yocto 源站镜像）
INHERIT += "own-mirrors"
SOURCE_MIRROR_URL = "https://downloads.yoctoproject.org/mirror/sources/"

# 复用/生成 tarball：以后换机器或重装可直接复用，不再重新 clone
BB_GENERATE_MIRROR_TARBALLS = "1"
DL_DIR ?= "${TOPDIR}/downloads"

# git 只取浅历史，减少拉取量
BB_GIT_SHALLOW = "1"
BB_GIT_SHALLOW_DEPTH = "1"

# 并行度按机器核数调整
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"
```

### 代理（如有）

BitBake 默认会过滤环境变量，需显式放行（kirkstone 用 `BB_ENV_PASSTHROUGH_ADDITIONS`）：

```conf
BB_ENV_PASSTHROUGH_ADDITIONS = "http_proxy https_proxy ftp_proxy no_proxy"
```

或在 `conf/site.conf` 里写死：

```conf
http_proxy = "http://127.0.0.1:7890"
https_proxy = "http://127.0.0.1:7890"
```

### GitHub 加速（可选，自担风险）

只影响 `git clone`，可临时用镜像前缀：

```bash
git config --global url."https://ghproxy.net/https://github.com/".insteadOf "https://github.com/"
# 需要时可移除：
# git config --global --unset url."https://ghproxy.net/https://github.com/".insteadOf
```

> `kas checkout` 的层仓库若网络差，README 里也提到：**预置本地已有 clone**，kas 检测到目录存在即跳过。

---

## 3. 复用旧构建缓存（只读镜像）

旧构建（`tegra-demo-distro/build/`）的下载与 sstate 可直接只读复用，磁盘不够时不必复制：

```conf
DL_DIR ?= "/旧路径/build/downloads"
SSTATE_DIR ?= "${TOPDIR}/sstate-cache"
SSTATE_MIRRORS = "file://.* file:///旧路径/build/sstate-cache/PATH"
```

---

## 4. 建议节奏

| 时间 | 动作 |
| --- | --- |
| 第 1 天 | `kas shell` → `bitbake --runall=fetch embedai-image`，反复重跑补漏 |
| 第 1–2 天 | 挂机继续 fetch，直到重跑无新下载 |
| 第 2 天起 | 加 `BB_NO_NETWORK="1"` → `kas build kas.yml` 离线编译 |
| 之后 | 依赖 `DL_DIR` + `SSTATE_DIR`，再构建基本不碰网络 |

---

## 5. 常用排查

```bash
bitbake --runall=fetch embedai-image   # 再跑一次，无输出=已齐
bitbake -e embedai-image | grep ^DL_DIR=     # 确认下载目录
bitbake -e <recipe> | grep -E '^SRC_URI|^S='
kas dump kas.yml                             # 查看最终展开配置
```
