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

#### `--runall` 是什么

普通 `bitbake embedai-image` 会跑目标的默认任务 `do_build`：调度器沿着任务依赖图，**边 fetch 边编译**（fetch 与 compile 交错并行），所以下载慢时整个构建都被拖住，也难判断卡在哪一步。

`--runall=<task>` 的意思是：**对目标依赖树里的所有 recipe，只执行指定的这个任务**。于是：

```
bitbake --runall=fetch embedai-image
# 等价于：对整棵依赖树里每个 recipe 跑 do_fetch，到此为止（不编译）
```

- 它仍然用正常的依赖解析，所以拉到的正是构建会用到的全部源码。
- 因为只跑 fetch，任务之间几乎无依赖，可以最大化并行下载。
- 已下载的会命中 `DL_DIR`，**可中断、可重跑**，反复执行直到不再有新下载。

> **`--runall=fetch` 与 `-c fetchall` 的区别**
>
> - `-c fetchall` 跑的是一个叫 `do_fetchall` 的**伪任务**，它靠 `[recrdeptask] = "do_fetch"` 递归触发依赖项的 `do_fetch`。该任务定义在早期 OE-Core 的 `base.bbclass`：
>   ```bitbake
>   addtask fetchall after do_fetch
>   do_fetchall[recrdeptask] = "do_fetch"
>   ```
>   但**当前 OE-Core 的 `base.bbclass` 已不再定义它**，所以在 kirkstone/scarthgap 等新版本上 `-c fetchall` 属遗留用法（可能直接报 "No such task"）。
> - `--runall=fetch` 是 **BitBake 调度器级选项**：直接对目标 task graph 里的每个 recipe 运行 `do_fetch`，不依赖那个伪任务，覆盖更完整、行为更明确。
> - 两者都是**只下载、不编译**，且可中断重跑；新版本统一用 `--runall=fetch`。
>
> 相关选项：`--runonly=<task>` 只跑指定任务且不做依赖递归；`-k`（`--continue`）出错不中断。

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

## 6. fetch 相关命令对比

| 命令 | 范围 | 编译依赖？ | 用途 |
| --- | --- | --- | --- |
| `bitbake -c fetch <recipe>` | **单个 recipe**（不递归依赖） | 否 | 补某个缺源 |
| `bitbake --runall=fetch <target>` | 目标**整棵依赖树** | 否 | 首次预下载（推荐） |
| `bitbake -c fetchall <target>` | 老伪任务（当前 OE-Core 已移除） | 否 | 遗留写法 |

要点：

- `bitbake -c fetch <recipe>` **只下载这一个 recipe 的 `SRC_URI`，不编译任何东西，也不会去 fetch 它的依赖**。对 image 目标用它几乎没用（image recipe 自身通常没有源码），预下载整棵树必须用 `--runall=fetch`。
- 三者都**不编译**；"编译依赖包"是 `do_build` 默认链路才会做的事。`-c <task>` 的本质是"只跑到这个任务为止"。
- 需要连依赖一起跑指定任务时才用 `--runall`；只想对单个 recipe 做某步就用 `-c`。
