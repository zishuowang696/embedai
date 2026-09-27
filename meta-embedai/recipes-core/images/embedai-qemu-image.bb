DESCRIPTION = "embedai 虚拟开发板镜像（QEMU aarch64，CPU-only）：验证发行版启动 + 本地推理链路。"
LICENSE = "MIT"

# 复用 OE-Core 的精简镜像（packagegroup-core-boot），再加 SSH 管理入口。
require recipes-core/images/core-image-minimal.bb

IMAGE_FEATURES += "ssh-server-openssh"

# QEMU 无 Jetson GPU：装 CPU-only llama.cpp（llama-cpp 按 MACHINE_FEATURES 自动关 CUDA）。
# 配 Qwen2.5-0.5B Q2_K 小模型 + llama-demo；llama-boot-demo 开机跑一次推理并打标记（CI 冒烟）。
# 注意：core-image-minimal 硬设 IMAGE_INSTALL，只认 CORE_IMAGE_EXTRA_INSTALL。
CORE_IMAGE_EXTRA_INSTALL += "llama-cpp llama-model-qwen llama-demo llama-boot-demo"
