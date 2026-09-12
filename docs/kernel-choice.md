# 内核选择：为什么是 `linux-yocto`，能不能换成 NVIDIA 官方内核

## 结论（TL;DR）

- 本项目当前使用 **`linux-yocto` 6.18**，这是上游 **tegra-demo-distro 的默认值**，**不是 KAS 配置错误**。
- 上游是在 linux-yocto 补齐 Orin/Thor 支持后，**主动**把默认从 NVIDIA 下游内核切回 linux-yocto 的。
- 若确实需要 NVIDIA 下游内核（L4T 对齐），在 `meta-embedai/conf/distro/embedai.conf` 覆盖一行即可；但会改变 sstate 签名、需重编。

## 当前配置链路

```
meta-embedai/conf/distro/embedai.conf
  └─ require conf/distro/include/tegrademo.inc        (来自 tegra-demo-distro 的 meta-tegrademo)
       └─ TEGRA_DEFAULT_KERNEL ?= "linux-yocto"
          PREFERRED_PROVIDER_virtual/kernel:tegra = "${TEGRA_DEFAULT_KERNEL}"
```

而 meta-tegra 自身的弱默认（会被上面覆盖）是：

```
meta-tegra/conf/machine/include/tegra-common.inc
  └─ PREFERRED_PROVIDER_virtual/kernel ?= "linux-noble-nvidia-tegra"
```

因为 `tegrademo.inc` 用的是强赋值 `=`（`:tegra` override），所以最终生效的是 **`linux-yocto`**。

## 上游为什么切回 linux-yocto（证据）

tegra-demo-distro 的提交历史里有一段反复：

| 提交 | 日期 | 内容 |
|------|------|------|
| `46e1b53` | 2026-06-25 | 默认切到 `linux-noble-nvidia-tegra`，注释写明是**临时**的：*"until linux-yocto support is available for both Orin and Thor targets"* |
| `0281ffd` | 2026-07-24 | 删除该注释，默认**改回** `linux-yocto` |

`0281ffd` 的 diff 原文：

```diff
-# Keeping the NVIDIA downstream kernel as the
-# default, until linux-yocto support is
-# available for both Orin and Thor targets.
-TEGRA_DEFAULT_KERNEL ?= "linux-noble-nvidia-tegra"
+TEGRA_DEFAULT_KERNEL ?= "linux-yocto"
 PREFERRED_PROVIDER_virtual/kernel:tegra = "${TEGRA_DEFAULT_KERNEL}"
```

含义：当 linux-yocto 已经能同时支持 Orin 和 Thor 后，上游就不再需要临时使用 NVIDIA 下游内核，于是切回了 linux-yocto。本仓库 pin 的 `7645ec1` 已包含这次回退。

## 这不是 KAS 引入的问题

即使采用官方 tegra-demo-distro 的 git submodule 方式、以 `distro = tegrademo` 构建，结果同样是 linux-yocto——因为默认值就在 `tegrademo.inc` 里。KAS 只是按 `kas.yml` 拉取并 pin 了这个 commit，没有改变内核选择。

## 两种内核对比

| | `linux-yocto`（当前） | `linux-noble-nvidia-tegra` |
|---|---|---|
| 来源 | 上游 Linux + Yocto 配置 | NVIDIA 下游 / L4T r39.2（Ubuntu 6.8.12） |
| 版本 | 6.18 | 6.8 |
| 上游态度 | tegrademo 当前默认 | 仅在 linux-yocto 未覆盖目标时临时使用 |
| NVIDIA 驱动 | 通过树外模块 `nvidia-kernel-oot` 提供 | 内核内自带 |
| 适用 | 通用、与上游一致 | 需与特定 L4T 版本严格对齐时 |

> 用 linux-yocto 并不等于放弃 NVIDIA 能力：meta-tegra 会针对它构建 `nvidia-kernel-oot` 树外模块（配置里可见按 `PREFERRED_PROVIDER_virtual/kernel` 是否含 `linux-yocto` 决定编译参数），CUDA/TensorRT 走该路径工作。

## 如何切换到 NVIDIA 下游内核

在 `meta-embedai/conf/distro/embedai.conf` 的 `require` 之后加一行（强赋值覆盖弱默认）：

```bb
TEGRA_DEFAULT_KERNEL = "linux-noble-nvidia-tegra"
```

或者更彻底地：不继承 `tegrademo.inc`，让 meta-tegra 的默认（`linux-noble-nvidia-tegra`）直接生效，同时自行设置 distro 其余项。

**注意**：切换内核会改变 sstate 签名，既有编译缓存全部作废，需重新全量编译。

## 相关链接

- **tegra-demo-distro**（`tegrademo.inc` 所在）：<https://github.com/OE4T/tegra-demo-distro>
- **meta-tegra**（内核 recipe 与机器默认）：<https://github.com/OE4T/meta-tegra>
- **linux-yocto**（上游内核）：<https://git.yoctoproject.org/linux-yocto>
- **NVIDIA L4T 内核源码**：<https://gitlab.com/nvidia/nv-tegra/3rdparty/canonical/linux-noble>
