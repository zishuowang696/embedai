# 04 · 裁剪策略（资源极限留给 AI）

目标：让镜像尽可能小、可编译范围尽可能少，把算力/内存留给 AI 负载。

## 已做的裁剪

| 项 | 位置 | 说明 |
|----|------|------|
| 无 GUI / 桌面栈 | `meta-embedai/recipes-core/images/embedai-image.bb` | 只装 `packagegroup-core-boot` + `packagegroup-core-ssh-openssh`，SSH 作为唯一管理入口 |
| AI 计算包暂不装 | 同上（注释块） | `cudnn` / `tensorrt-core` / `tegra-libraries-cuda` 等按需再加 |
| 去掉 PAM | `meta-embedai/conf/distro/embedai.conf` | `DISTRO_FEATURES:remove = "pam"` |
| 去掉虚拟化 | 同上 | `DISTRO_FEATURES:remove = "virtualization"`（不用 docker 时省一大票包） |
| 去掉通用互联特性 | `embedai.conf` | `DISTRO_FEATURES:remove = "3g nfc bluetooth nfs zeroconf debuginfod gobject-introspection-data"`（**保留** wifi / alsa / ptest / opengl） |
| 去掉相机/CAN 模块 | `kas.yml` | `MACHINE_EXTRA_RRECOMMENDS:remove = "nvidia-kernel-oot-cameras nvidia-kernel-oot-canbus"` |
| 预编译 OP-TEE | `kas.yml` | `USE_PREBUILT_OPTEE = "1"`（免从源码编 `optee-os`） |
| CUDA 限定架构 | `llama-cpp` recipe | `CUDA_ARCHITECTURES = "87"`（只编 Orin，省多架构 fatbin） |
| 体积可测 | `kas.yml` | `BUILDHISTORY_FEATURES = "image"` + `INHERIT buildhistory` → 产出 `installed-package-sizes.txt` |

## 可选的进一步裁剪

| 项 | 改法 | 影响 |
|----|------|------|
| 初始化系统 | `INIT_MANAGER = "mdev"`（替换默认 `systemd`） | 省 systemd 及其依赖；但 NVIDIA 用户态服务默认依赖 systemd，上 CUDA/TensorRT 前需评估 |
| 打包格式 | `PACKAGE_CLASSES = "package_ipk"`（替换 `package_rpm`） | 少编 rpm-native/db，构建更轻 |
| 图形特性 | 从 `DISTRO_FEATURES` 去掉 `opengl`/`x11`/`wayland` | 若确认无显示需求，可省图形栈；注意 `embedai-image.bb` 的 `REQUIRED_DISTRO_FEATURES = "opengl"` 需同步去掉 |
| 内核 | 见 [03 · 内核选择](03-kernel.md) | 换内核会改变签名、需重编 |

## 重要提醒：动 `DISTRO_FEATURES` 要慎重

- **改 `DISTRO_FEATURES` / `MACHINE_FEATURES` 会让大量 sstate 签名失效**（很多 recipe 的哈希含 distro features）→ 触发范围重建，**CI 缓存同样作废**。**一次规划、集中改；定型后别反复。**
- **优先用 image 级裁剪**（不伤签名，只重签镜像）：
  - `IMAGE_INSTALL:remove` / `BAD_RECOMMENDATIONS` / `PACKAGE_EXCLUDE` / `IMAGE_FEATURES`
  - `MACHINE_EXTRA_RRECOMMENDS:remove` —— 对 **RRECOMMENDS 类**最有效（如相机/CAN 模块：**又省编译又缩体积**）
- **RDEPENDS 类拿不掉编译**：如 `3g` / `nfc` / `bluetooth`，经 `packagegroup-base-extended` 是**强依赖**（`RDEPENDS`），image 级只能"不装"（`PACKAGE_EXCLUDE`），**仍会被构建**；想省编译只能动 features。
- 优先顺序建议：先拿到能启动的基线镜像，再逐项裁剪并验证启动/SSH。

## native 大头的来源（实测依赖图）

编译耗时的"大头"是 `rust-native` → `llvm-native`。用 `bitbake -g` 逆查，根在 **Tegra 启动链**：

```
tegra-bootfiles → tegra-eks-image → optee-nvsamples-native
  → (optee-l4t.inc) python3-cryptography-native   # cryptography 新版是 Rust 写的
    → python3-maturin-native / setuptools-rust-native → rust-native → llvm-native
```

- `USE_PREBUILT_OPTEE = "1"` 能去掉 **`optee-os`**（一个大件），但 **EKS 支线的 `optee-nvsamples-native` 仍在** → rust/llvm **仍会编一次**（进 sstate 后不再）。
- 顺带辟谣：**不是 OpenGL/mesa**（`mesa` 不在 Jetson 依赖图里，只属于 qemu 配置）。

> 排查方法：`bitbake -g embedai-image` → 在 `task-depends.dot` 里**反向找上游**，一层层剥。

## 验证

```bash
kas shell kas.yml -c "bitbake -p"                 # 解析校验（快）
kas shell kas.yml -c "bitbake -e embedai-image | grep ^DISTRO_FEATURES="
```
