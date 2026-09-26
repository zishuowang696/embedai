# 虚拟开发板：在 QEMU 上跑 embedai（无需 Jetson 硬件）

没有 Jetson 也能验证 embedai：用上游 QEMU 的 **aarch64 虚拟板**构建一份精简镜像并启动。适合学习、CI 冒烟、以及在没有板子时验证发行版改动。

## 能验证什么 / 不能验证什么

| | 虚拟板（QEMU aarch64） |
| --- | --- |
| 发行版结构、`kas` 配置、启动链 | ✅ |
| systemd、串口控制台、网络（slirp） | ✅ |
| aarch64 工具链/二进制 | ✅ |
| Jetson GPU / CUDA / TensorRT | ❌ QEMU 没有 Jetson GPU/NPU |
| 刷机（`jetson-flash`）、TF-A/U-Boot 真机流程 | ❌ |

> 一句话：虚拟板验证“发行版能不能起来、管理面通不通”，**不验证 AI 算力**。

## 机器与镜像

- 机器：`qemuarm64-embedai`（`meta-embedai/conf/machine/qemuarm64-embedai.conf`，`require` 上游 `qemuarm64.conf`）
- 镜像：`embedai-qemu-image`（复用 `core-image-minimal` + SSH，**不含** llama/CUDA/TensorRT）
- 叠加配置：`kas-qemu.yml`（只覆盖 `machine` 与 `target`，复用 `kas.yml` 的全部层）

## 构建与启动

```bash
# 构建（QEMU aarch64）
kas build kas.yml:kas-qemu.yml

# 启动并进串口控制台
kas shell kas.yml:kas-qemu.yml -c "runqemu qemuarm64-embedai nographic"
```

登录：`core-image-minimal` 默认带 `debug-tweaks`，**root 空密码**——仅用于本地/CI 验证，勿用于生产。

## CI

`.github/workflows/qemu-smoke.yml`：在 GitHub runner 上构建并做一次 `runqemu` 启动冒烟（检测 `login:` / systemd 就绪），无需硬件。

## 说明与限制

- QEMU aarch64 在 x86 runner 上走 TCG 软件模拟，启动较慢（分钟级），不适合性能测试。
- 修改 `meta-embedai` 里的 distro/image 后，用虚拟板能快速验证“是否还能构建/启动”，再上真机。
- AI 相关的配方（llama-cpp/CUDA/TensorRT）在虚拟板镜像里**故意不装**，保持最小、可启动。
