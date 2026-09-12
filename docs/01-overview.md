# 01 · 项目概览与目标硬件

## 项目定位

**EmbedAI** —— 基于 NVIDIA Jetson 的 **AI 网关**镜像：精简系统（无 GUI / 无桌面栈，只留 SSH 管理入口），把资源极限留给 AI 计算。

- 自建 distro：`embedai`
- 自建镜像：`embedai-image`
- 自建层：`meta-embedai/`（仓库内唯一版本化内容）
- 构建系统：KAS（见 [02 · 从 submodule 到 KAS](02-kas.md)）

## 目标硬件

**Jetson Orin Nano Super**（开发者套件）：

| 项 | 值 |
|----|----|
| 载板 | P3768-0000 |
| 模组 | P3767-0005（Orin Nano 8GB Super） |
| 启动介质 | NVMe（根文件系统在 `nvme0n1p1`） |
| Yocto machine | `jetson-orin-nano-devkit-nvme` |

machine 配置链路：

```
jetson-orin-nano-devkit-nvme.conf
  ├─ require conf/machine/include/orin-nano.inc   # Super 配置：BOARDSKU=0005、super DTB、nvpmodel
  └─ require conf/machine/include/p3768.inc       # 载板外设（WiFi/BT 等）
```

`orin-nano.inc` 中的关键项：

```bb
TEGRA_BOARDSKU ?= "0005"
NVPMODEL ?= "nvpmodel_p3767_0003_super"
KERNEL_DEVICETREE ?= "tegra234-p3768-0000+p3767-0005-nv-super.dtb"
```

## 构建入口

```bash
kas checkout kas.yml   # 拉齐所有层到锁定 commit
kas build kas.yml      # 构建 embedai-image
kas shell kas.yml      # 进入 bitbake 环境
```

详见 [05 · GitHub Actions 编译](05-ci.md) 与 [06 · 环境与踩坑](06-gotchas.md)。
