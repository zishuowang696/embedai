DESCRIPTION = "EmbedAI AI-gateway image: no GUI, resources reserved for AI."
LICENSE = "MIT"

inherit core-image features_check

REQUIRED_DISTRO_FEATURES = "opengl"

# AI 网关：只留 SSH 管理入口，不装任何图形/桌面栈
IMAGE_FEATURES += "ssh-server-openssh"

CORE_IMAGE_BASE_INSTALL += " \
    packagegroup-core-boot \
    packagegroup-core-ssh-openssh \
    llama-cpp \
    llama-model-qwen \
    llama-demo \
    "

# ---- GPU 加速：llama-cpp 走 meta-tegra 的 cuda bbclass，已自动 RDEPENDS tegra-libraries-cuda ----
# 如需额外 AI 计算包（确认 meta-tegra 实际包名后追加）：
#   cudnn
#   tensorrt-core
#   cuda-cudart
