DESCRIPTION = "embedai 虚拟开发板镜像（QEMU aarch64，无 GPU/NPU）：验证发行版启动与管理面。"
LICENSE = "MIT"

# 复用 OE-Core 的精简镜像（packagegroup-core-boot），再加 SSH 管理入口。
# 虚拟板上不装 llama-cpp / CUDA / TensorRT（QEMU 无 Jetson GPU）。
require recipes-core/images/core-image-minimal.bb

IMAGE_FEATURES += "ssh-server-openssh"
