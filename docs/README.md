# EmbedAI 文档

本目录是项目文档总纲，按章节拆成独立文件，便于分别维护。

> **关于“总文件包含各章”**：Markdown 没有原生 include 语法，GitHub 也不会做内容内联。
> 这里采用**链接式章节**：本文件作为目录，链接到各独立章节；GitHub 直接渲染，无需构建工具。
> 若将来要真正合并成单文件/站点，可用 mdBook / MkDocs / pandoc 等对同样的文件做预处理。

## 章节

| # | 章节 | 内容 |
|---|------|------|
| 01 | [项目概览与目标硬件](01-overview.md) | 项目定位、目标板 Orin Nano Super、构建入口 |
| 02 | [从 submodule 到 KAS](02-kas.md) | 为什么用 KAS、对比与价值、项目链接 |
| 03 | [内核选择](03-kernel.md) | 为什么是 linux-yocto、能否换 NVIDIA 官方内核 |
| 04 | [裁剪策略](04-trimming.md) | 已做/可做的精简项与重编影响 |
| 05 | [GitHub Actions 编译](05-ci.md) | CI 结构、6h 上限与分次续跑、sstate 缓存 |
| 06 | [环境与踩坑](06-gotchas.md) | 宿主环境、已知坑位、常用命令 |
| 07 | [本地构建（国内网络优化）](07-local-build.md) | 先 fetch 后 build、镜像与代理、缓存复用 |
| 08 | [BitBake 速查](08-bitbake.md) | 命令、DEPENDS/RDEPENDS、sstate 签名、变量覆盖 |
| 09 | [查依赖](09-dependencies.md) | 谁依赖了我的层 / 我依赖了谁 |
| 10 | [GitHub 下载加速与镜像测速](10-github-mirrors.md) | 国内代理前缀、实测速度、缓存拉取 |

## 项目链接

- KAS：<https://github.com/siemens/kas> · 文档 <https://kas.readthedocs.io>
- 官方 tegra-demo-distro：<https://github.com/OE4T/tegra-demo-distro>
- meta-tegra：<https://github.com/OE4T/meta-tegra>
- OpenEmbedded Core：<https://github.com/openembedded/openembedded-core>
- meta-openembedded：<https://github.com/openembedded/meta-openembedded>
- 本仓库：<https://github.com/zishuowang696/embedai>
