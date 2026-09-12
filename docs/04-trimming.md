# 04 · 裁剪策略（资源极限留给 AI）

目标：让镜像尽可能小、可编译范围尽可能少，把算力/内存留给 AI 负载。

## 已做的裁剪

| 项 | 位置 | 说明 |
|----|------|------|
| 无 GUI / 桌面栈 | `meta-embedai/recipes-core/images/embedai-image.bb` | 只装 `packagegroup-core-boot` + `packagegroup-core-ssh-openssh`，SSH 作为唯一管理入口 |
| AI 计算包暂不装 | 同上（注释块） | `cudnn` / `tensorrt-core` / `tegra-libraries-cuda` 等按需再加 |
| 去掉 PAM | `meta-embedai/conf/distro/embedai.conf` | `DISTRO_FEATURES:remove = "pam"` |
| 去掉虚拟化 | 同上 | `DISTRO_FEATURES:remove = "virtualization"`（不用 docker 时省一大票包） |

## 可选的进一步裁剪

| 项 | 改法 | 影响 |
|----|------|------|
| 初始化系统 | `INIT_MANAGER = "mdev"`（替换默认 `systemd`） | 省 systemd 及其依赖；但 NVIDIA 用户态服务默认依赖 systemd，上 CUDA/TensorRT 前需评估 |
| 打包格式 | `PACKAGE_CLASSES = "package_ipk"`（替换 `package_rpm`） | 少编 rpm-native/db，构建更轻 |
| 图形特性 | 从 `DISTRO_FEATURES` 去掉 `opengl`/`x11`/`wayland` | 若确认无显示需求，可省图形栈；注意 `embedai-image.bb` 的 `REQUIRED_DISTRO_FEATURES = "opengl"` 需同步去掉 |
| 内核 | 见 [03 · 内核选择](03-kernel.md) | 换内核会改变签名、需重编 |

## 重要提醒

- **任何 distro 级改动都会改变 sstate 签名**，既有编译缓存（含 CI 缓存）全部作废，需重新全量编译。裁剪应一次规划、集中改，避免反复重编。
- 优先顺序建议：先拿到一个能启动的基线镜像，再逐项裁剪并验证启动/SSH。
- 编译耗时的“大头”是 native 工具链：`qemu-native`、`gcc`/`llvm`、`rust-native`（被 `python3-cryptography-native` 间接拉入）。若能从依赖里去掉引入 rust 的包，可省数小时。

## 验证

```bash
kas shell kas.yml -c "bitbake -p"                 # 解析校验（快）
kas shell kas.yml -c "bitbake -e embedai-image | grep ^DISTRO_FEATURES="
```
