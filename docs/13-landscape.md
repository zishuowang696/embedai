# 开源同类／相邻项目与我们的空位

> 数据取自 GitHub（2026-09，star 数近似）。目的是看清竞争与空位，指导定位与内容。

## 1. 直接相关

| 项目 | 规模 | 它做什么 | 与我们重叠 | 差距（我们的空位） |
| --- | --- | --- | --- | --- |
| **dusty-nv/jetson-containers** | ~4.9k★ | Jetson 上的 AI **容器**（ML 开发便利） | "在 Jetson 上跑模型" | 面向**开发便利**，不是生产用的**最小系统**；无发行版/OTA/稳定性保障 |
| **dusty-nv/jetson-inference** | ~9.0k★ | "Hello AI World"：用 TensorRT 在 Jetson 上部署推理（示例/教程） | 模型部署入门 | 偏**示例**，非可交付的生产发行版 |
| **OE4T/meta-tegra** | ~580★ | Jetson 的 Yocto **BSP 层** | 底层构建 | 只有 BSP，**不含**模型部署流水线/稳定性能保障 |
| **OE4T/tegra-demo-distro** | ~123★ | meta-tegra 的**参考/演示** distro（embedai 的前身基线） | 发行版骨架 | 演示性质，非产品化 |
| **foundriesio/meta-lmp** | ~45★ | 边缘 Yocto 发行版 + OTA（Qualcomm 旗下） | 边缘 Linux + OTA | 偏通用容器平台，非 AI 专用；商业化主导 |
| **toradex/torizon** | — | 容器化边缘 Linux + OTA + Cloud | 边缘 Linux + OTA | 绑定 Toradex 硬件；商业云 |
| **balena-os/balena-engine** | ~743★ | 嵌入式容器引擎（Balena 生态） | 边缘容器 | 容器/云导向，非 AI 专用最小镜像 |
| **mendersoftware/mender** | ~1.2k★ | OTA 更新 | 升级不砖 | 只是 OTA 框架，与发行版解耦 |
| **rauc/rauc** | ~1.2k★ | 安全 OTA | 升级不砖 | 同上 |
| **pantavisor/pantavisor** | ~75★ | 近裸金属多容器 OS 管理 | 边缘系统管理 | 通用，非 AI |
| **frigate** | ~36k★ | 本地 AI 摄像头 NVR（应用） | 边缘 AI 应用 | 应用层，不是发行版 |
| **ultralytics** | ~62k★ | YOLO 模型/训练（模型侧） | 模型 | 模型侧 |

## 2. 结论：空位在哪

现有生态分四类：**开发容器/示例**（jetson-containers、jetson-inference）、**BSP/参考 distro**（meta-tegra、tegra-demo-distro）、**通用边缘 OS+OTA**（Balena/Torizon/Foundries）、**OTA 框架**（Mender/RAUC）、**应用/模型**（Frigate/Ultralytics）。

**没有人做**：面向生产的、**开源、最小、可复现**、以"**模型 → 设备**"为核心、带**稳定/性能基准**与 **OTA** 的发行版（Jetson 优先）。

> 一句话：**开发体验别人做了，生产交付（更小、更稳、可复现、可更新、有数据）没人做。**

## 3. 怎么不撞车

- **不与 jetson-containers 争"跑 demo"**：争"上生产"——镜像更小、可复现（KAS 锁版本）、有稳定性/性能保障、可 OTA。
- **不与 meta-tegra 争 BSP**：站在它（与 tegra-demo-distro）之上，做"**AI 部署层 + 保障层**"。
- **不与 Mender/RAUC 争 OTA**：集成它们，而不是重造。
- **明确边界**：虚拟板（QEMU）不跑 GPU/CUDA——诚实标注，反而增加可信度。

## 4. 内容切入点（差异化）

- **对比实测**：embedai vs JetPack vs jetson-containers——镜像大小、启动时间、内存占用、模型延迟/功耗（用真实数字）。
- **可复现**：一个 `kas.yml` 锁死整树；换机器/CI 结果一致。
- **稳定/性能**：soak test 数据、降频/温度曲线、TensorRT engine 调优前后对比。
- **国内工程**：GitHub 下载加速、缓存流水线（已发文章）。
