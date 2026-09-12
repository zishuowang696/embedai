# EmbedAI — Jetson AI 网关

[English](README.en.md) | 中文

[![build](https://github.com/zishuowang696/embedai/actions/workflows/embedai.yml/badge.svg)](https://github.com/zishuowang696/embedai/actions/workflows/embedai.yml)
![license](https://img.shields.io/badge/license-MIT-blue.svg)
![platform](https://img.shields.io/badge/platform-Jetson%20Orin%20Nano%20Super-76b900.svg)

裁剪 tegra，把资源极限留给 AI。

## 项目定位

基于 NVIDIA Jetson（Orin Nano **Super** DevKit NVMe）的 **AI 网关**：
- 精简系统：无 GUI / 无桌面栈，只留 SSH 管理入口
- 自建 distro 与 image：`embedai` / `embedai-image`
- 资源极限留给 AI：GPU/CUDA 计算能力保留，其余能省则省

> 详细文档见 [docs/](docs/README.md)（分章节：硬件、KAS、内核、裁剪、CI、踩坑）。

## 构建方式：KAS

本仓库用 [KAS](https://kas.readthedocs.io/) 管理整个 Yocto 构建，替代 tegra-demo-distro 的 git submodule 方式。

```
~/tegra-kas/
├── kas.yml                      # KAS 配置：仓库 + 层 + distro/machine/target
├── meta-embedai/                 # 自建层
│   ├── conf/
│   │   ├── layer.conf
│   │   └── distro/embedai.conf   # 自建 distro
│   ├── recipes-core/images/
│   │   └── embedai-image.bb      # 自建精简镜像
│   └── recipes-bsp/arm-trusted-firmware/
│       └── arm-trusted-firmware_%.bbappend   # Python 3.10 兼容补丁
└── build/                       # kas 生成的构建目录（不入库）
```

### 依赖

- `kas`（5.3+，`pip install kas`）
- 磁盘：构建 Jetson 镜像约需 ~60G+（可复用旧缓存）

### 快速开始

```bash
kas checkout kas.yml      # 拉取并锁定各层
kas build kas.yml         # 构建 embedai-image
kas shell kas.yml         # 进入 bitbake 环境
kas dump kas.yml          # 查看最终展开配置
```

首次构建生成 `kas.lock` 固定各仓库版本。

### 复用旧构建缓存（零复制，只读镜像）

旧构建（`tegra-demo-distro/build/`）的产物可直接当只读源复用，磁盘不够时不用复制：

```
DL_DIR ?= "/旧路径/build/downloads"                        # 源码包（版本锁定一致→全命中）
SSTATE_DIR ?= "${TOPDIR}/sstate-cache"                      # 自己的新缓存
SSTATE_MIRRORS = "file://.* file:///旧路径/build/sstate-cache/PATH"  # 编译产物只读镜像
```

## 已解决的坑

| 问题 | 原因 | 解决 |
|------|------|------|
| KAS 5.3 `layers` schema 报错 | 新版本不再支持 `path`/`priority` | 改为 `<repo.path>/<layer名>` + `prio`；bitbake 需 `layers: {'': disabled}` |
| `tegra_distro_update_bblayersconf` 崩溃（`sanity_conf_read` 未定义） | 版本号不匹配才走更新逻辑 | `bblayers_conf_header` 补 `TD_BBLAYERS_CONF_VERSION = "embedai-7"` |
| GitHub 超时拉不到仓库 | 网络不稳定 | 从本地已有 clone 预置仓库目录，kas 检测存在即跳过 |
| `ImportError: cannot import name 'UTC' from 'datetime'` | meta-tegra 的 TF-A 配方需 Python 3.11+，宿主是 3.10 | `meta-embedai` 里用 `timezone.utc` 等价替换（bbappend） |

## 下一步（资源精简清单）

- [ ] 确认 meta-tegra 实际包名后，在 `embedai-image.bb` 追加 AI 包：`cudnn`、`tensorrt-core`、`tegra-libraries-cuda` 等
- [ ] 自建 `ollama` recipe（ARM64 原生部署，无需 docker）
- [ ] 按需去掉 `pam` / `virtualization` distro 特性（`embedai.conf` 里有注释开关）
- [ ] 构建通过后删除旧 `build/tmp`、`build/cache` 腾空间

## License

MIT
