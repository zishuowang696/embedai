# 为什么从 git submodule 切到 KAS

本仓库原先是照着 NVIDIA 官方 **tegra-demo-distro** 的方式用 git submodule 管理多个上游层。迁移到 [KAS](https://github.com/siemens/kas) 之后，用一个声明式 `kas.yml` 取代了手工同步 submodule 的全部工作。

## 对比

| 维度 | tegra-demo-distro（git submodule） | 本仓库（KAS） |
|------|-----------------------------------|---------------|
| 多仓库管理 | 每层一个 submodule，需逐个子模块 `init/update`、手工对齐版本 | 一个 `kas.yml` 声明所有 repo + 层，`kas checkout` 一次搞定 |
| 版本一致性 | 依赖 submodule 指针，各自推进，易漂移 | 每个 repo 锁到 **commit**，整树是一个可复现快照 |
| 换层 / 加层 | 手工改 submodule + 改 bblayers，易错 | `repos:`/`layers:` 加几行即可（本项目已有 8 个 repo） |
| 构建入口 | 记住一串 bitbake/环境命令 | `kas build / shell / dump`，配置即文档 |
| 可裁剪性 | 在官方 distro 上改，层层叠叠 | distro/image/层都归 `meta-embedai` 自建，想删就删 |
| CI / 自动化 | 脚本难维护 | kas 命令可直接进 GitHub Actions |

## KAS 带来的能力（举例）

- **可扩展**：以后想加 OpenWrt 相关 layer（或任何 OE 层），只需在 `kas.yml` 的 `repos:` 里加一个 repo、在 `layers:` 里声明路径与优先级，不用动 bblayers。
- **易用性**：日常只有三条命令——`kas checkout`（拉齐所有层到锁定 commit）、`kas build`（构建目标镜像）、`kas shell`（进 bitbake 环境做细活）。
- **可复现**：所有上游 commit 全部钉死在 `kas.yml`，换机器/上 CI 结果一致。

## 项目链接

- **KAS**（配置/构建工具）：<https://github.com/siemens/kas> · 文档 <https://kas.readthedocs.io>
- **官方 tegra-demo-distro**（git submodule 方案，本项目的前身基线）：<https://github.com/OE4T/tegra-demo-distro>
- **meta-tegra**（Jetson BSP 层）：<https://github.com/OE4T/meta-tegra>
- **meta-tegra-community**：<https://github.com/OE4T/meta-tegra-community>
- **OpenEmbedded Core**：<https://github.com/openembedded/openembedded-core>
- **meta-openembedded**（meta-oe 等）：<https://github.com/openembedded/meta-openembedded>
- **meta-virtualization**：<https://git.yoctoproject.org/meta-virtualization>
- **bitbake**：<https://github.com/openembedded/bitbake>
- **本仓库自建层** `meta-embedai/`（distro/image/TF-A 兼容补丁都在这里）

> 扩展方向备忘：要接入 OpenWrt 系内容时，先在 <https://layers.openembedded.org> 检索可用 layer，再加入 `kas.yml`。
