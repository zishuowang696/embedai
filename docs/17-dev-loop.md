# 开发迭代：让编译不再拖慢开发

## 问题
- 全量 `embedai-image` ≈ **8000+ 任务**；本机 7GB/4 核要数小时，还会疯狂换页。
- 每改一行就整镜像重编 = 开发节奏被毁。

## 三层策略（按收益排序）

### 1. 复用 sstate —— 最大收益
Yocto 的 sstate 缓存**按任务哈希复用**：配置/层版本一致时，第二次只重编改动部分。
- CI（16GB）负责"从零编全量"，结果持久化到 Release：`sstate-jetson` / `sstate-qemu`。
- 本地拉一份，增量构建直接命中：
  ```bash
  scripts/pull-sstate.sh          # 拉 sstate-jetson → build/sstate-cache
  scripts/pull-sstate.sh qemu     # 拉 sstate-qemu（qemuarm64）
  ```
- 之后本地 `kas build` 只编你改的 recipe 及其依赖。
- ⚠️ 命中要求**层 commit 一致**（kas.yml 已锁）；换 commit（如升级 meta-tegra）会导致大量失效——这是正常的，交给 CI 重建缓存。

### 2. 只编改动 —— 日常主力
不要每次整镜像：
```bash
kas shell kas.yml -c "bitbake <recipe>"             # 编单个 recipe
kas shell kas.yml -c "bitbake -c compile <recipe>"  # 只到 compile
kas shell kas.yml -c "bitbake -c devshell <recipe>"
```
改应用/内核时用 `devtool`（自动建 layer 覆盖 + 增量重建）：
```bash
kas shell kas.yml -c "devtool modify <recipe>"
kas shell kas.yml -c "devtool build <recipe>"
kas shell kas.yml -c "devtool finish <recipe> <layer>"
```

### 3. 精简镜像验证系统逻辑
- `embedai-qemu-image`（`core-image-minimal` + ssh）用 **qemuarm64** 构建：任务少、可本地起 QEMU，快速验证 systemd/网络/启动。
- 只有正式发布/烧录才编全量 `embedai-image`。

## 开发节奏对照
| 场景 | 做什么 | 预期 |
| --- | --- | --- |
| 改应用/脚本 | `devtool modify` + `bitbake <recipe>` | 分钟级 |
| 改内核/驱动 | `bitbake virtual/kernel`（增量续编） | 十几分钟 |
| 改系统/镜像 | 编 `embedai-qemu-image` + QEMU 启动 | 较快 |
| 出正式镜像 | 交给 **CI**（16GB + sstate 复用） | 后台跑 |
| 首次全量 | **别在本机 7GB 上做** | 用 CI |

## 硬件（根因）
- **内存是硬门槛**：Yocto 会并行多个 `cc1plus`（每个数百 MB），7GB 必然换页。建议 **16–32GB + SSD**，这是最直接的提速。
- 低内存主机：叠加 `local/kas-lowmem.yml`（`BB_NUMBER_THREADS=2` / `PARALLEL_MAKE=-j2`），慢机降并行**反而更快**。

## 一句话
**本机不做"从零全量"，只做"增量复用"**：
CI 编全量 → 存 sstate → 本地拉 sstate → 只编改动 → 精简镜像验证 → 出镜像回 CI。

## 附：eSDK（可扩展 SDK）——彻底离线单包开发

若想让本地**完全脱离全量构建**（也不需要构建树），用 eSDK：

- CI：`.github/workflows/esdk.yml`（手动触发）→ restore sstate → `populate_sdk_ext` → 分卷发布到 Release `esdk-latest`。
- 本地：
  ```bash
  cat esdk-*.part-* > esdk.sh && sh esdk.sh
  source <安装目录>/environment-setup-*
  devtool modify <recipe> && devtool build <recipe>   # 离线、分钟级
  ```
- eSDK = 交叉工具链 + 目标 sysroot + bitbake/devtool + **所需 sstate 子集**（体积较大，故分卷）。
