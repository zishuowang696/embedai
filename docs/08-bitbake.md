# 08 · BitBake 速查（结合本项目）

面向“二次开发出身、bitbake 内部不熟”的实用清单，例子都取自本仓库。

## 一、最常用的几条命令

配合 KAS 使用（在 bitbake 环境里执行）：

```bash
kas shell kas.yml -c "bitbake -p"                    # 只解析，不构建
kas shell kas.yml -c "bitbake -g embedai-image"      # 生成依赖图
kas shell kas.yml -c "bitbake -e virtual/kernel"     # 展开某 recipe 的最终变量
kas shell kas.yml -c "bitbake -c cleanall embedai-image"
```

| 命令 | 作用 |
|------|------|
| `bitbake -p` | 只解析所有 layer/recipe，验证配置（最快） |
| `bitbake -g <target>` | 输出 `pn-buildlist`（会构建的 recipe）和 `task-depends.dot`（任务依赖图） |
| `bitbake -e <recipe>` | 打印该 recipe 展开后的所有变量，排查“值为什么是这样” |
| `bitbake -c <task> <recipe>` | 只跑某个任务，如 `-c compile` / `-c cleanall` |
| `bitbake-layers show-layers` | 列出已启用层及优先级 |
| `bitbake-layers show-cross-depends` | 列出**层与层之间**的依赖 |
| `bitbake-layers show-recipes` | 列出 recipe 及提供它的层 |

## 二、依赖关系：`DEPENDS` vs `RDEPENDS`

| 变量 | 时机 | 含义 |
|------|------|------|
| `DEPENDS` | 构建期 | 编译这个 recipe 前必须先编好 |
| `RDEPENDS` | 运行期 | 装包时必须一起装的依赖 |

裁剪时最常混的就是这两个：**镜像变大通常是 `RDEPENDS` 拉进来的**，`DEPENDS` 只影响编译。

查“谁把它拉进来的”：

```bash
kas shell kas.yml -c "bitbake -g embedai-image"
# 生成的 build/pn-buildlist 列出所有会构建的 recipe
grep -i rust build/pn-buildlist
# task-depends.dot 里可以顺着边找上游
grep -i "rust-native" build/task-depends.dot
```

> 例：本项目日志里 `rust-native`/`llvm-native` 被 `python3-cryptography-native` 间接拉入，就是靠依赖图定位的。

## 三、为什么会全量重编：sstate 签名

- BitBake 为每个任务算一个**签名（signature）**；签名相同就从 `SSTATE_DIR` 取缓存、跳过执行。
- 签名取决于 recipe 内容 + 相关**配置变量**（`DISTRO_FEATURES`、`PACKAGECONFIG`、`MACHINE`、层优先级…）。
- 所以**改 distro feature、换内核、改层优先级 → 签名全变 → 全量重编**。这也是“裁剪要一次集中改”的原因。
- 相关目录：
  - `build/tmp/` 构建中间产物（`rm_work` 会及时清理 recipe 的 work 目录）
  - `build/sstate-cache/` 可复用的任务产物缓存
  - `build/downloads/`（`DL_DIR`）源码包

## 四、变量与覆盖（读懂“值为什么是它”）

- **弱默认 `?=` vs 强赋值 `=`**：`?=` 只在未定义时生效，`=` 直接覆盖。
  - 本项目内核就是这样被改掉的：meta-tegra 用 `?=` 默认 `linux-noble-nvidia-tegra`，而 `tegrademo.inc` 用 `=` 覆盖成 `linux-yocto`。
- **覆盖（override）优先级**：`pn-<recipe>` > `MACHINE`（`tegra`）> `DISTRO` > 通用；越具体越优先。
- **常用追加/删除**：`:append` / `:prepend` / `:remove`。
- **选定实现/版本**：`PREFERRED_PROVIDER_virtual/kernel`、`PREFERRED_VERSION_linux-yocto`。

实用查询：

```bash
# 最终内核 provider
kas shell kas.yml -c "bitbake -e virtual/kernel | grep ^PREFERRED_PROVIDER"
# 最终 DISTRO_FEATURES
kas shell kas.yml -c "bitbake -e embedai-image | grep ^DISTRO_FEATURES="
# 某变量的来源（含 include 链）
kas shell kas.yml -c "bitbake -e embedai-image | grep -A3 '^DISTRO ='"
```

## 五、查找“谁依赖我 / 我依赖谁”

- **recipe 级**：`bitbake -g <target>` → 看 `pn-buildlist` / `task-depends.dot`。
- **层（layer）级（构建内）**：`bitbake-layers show-cross-depends` 列出层间依赖。
- **外部谁依赖我的层**（构建外）：见 [09 · 查依赖](09-dependencies.md)。

## 六、本仓库的常见排查入口

```bash
kas shell kas.yml -c "bitbake -p"                              # 配置是否健康
kas shell kas.yml -c "bitbake -e embedai-image | grep ^DISTRO" # 发行版设置
kas shell kas.yml -c "bitbake-layers show-layers"             # 层与优先级
kas shell kas.yml -c "bitbake-layers show-cross-depends"      # 层依赖
```
