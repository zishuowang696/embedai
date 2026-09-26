# 定位：面向「AI 模型部署」的嵌入式 Linux 发行版

## 一句话
EmbedAI 是一个**精简、可复现的嵌入式 Linux 发行版**，目标是**把训练好的 AI 模型可靠地部署到边缘设备**：构建镜像 → 放入模型 → 交付上线。

## 判断：方向对，但"嵌入式 AI 发行版"太宽
- 通用 BSP / NVIDIA JetPack 解决的是"系统能跑起来"；EmbedAI 要解决的是"**模型能上、能稳、能更新**"。
- 真正的价值在 **模型 → 设备** 这条流水线，发行版只是底座。对外可以叫"发行版"，对内要把产品定义成**部署层**。

## 与现有方案的差异
| 方案 | 它解决什么 | EmbedAI 的不同 |
| --- | --- | --- |
| NVIDIA JetPack | Jetson 系统 + 驱动 + CUDA | 更精简、KAS 锁版本可复现、模型优先、思路可跨板 |
| Foundries.io（Linux microPlatform） | 边缘 Linux + OTA | 开源可自托管、聚焦模型部署流水线 |
| Edge Impulse | 训练/MLOps 侧 | 提供完整系统 + 部署层，而非只做训练 |
| 厂商 BSP | 单板可用 | 统一工作流，降低换板成本 |

## 产品应该长什么样（backlog）
1. **精简可复现底座**：KAS 管理、最小镜像（已在做）。
2. **模型部署流水线（核心）**：
   - `embedai-deploy`：输入 ONNX / GGUF / TFLite → 编译成目标运行时（TensorRT / RKNN / ONNXRuntime）→ 生成 systemd 服务；
   - 运行时抽象：同一模型在 Jetson 与其它 NPU 上用统一接口。
3. **可复现 + OTA**：A/B 升级、不砖。
4. **基准与可观测**：延迟 / 内存 / 功耗 / 精度 的标准化测量（也是内容素材）。
5. **CI**：镜像构建 + 启动冒烟（真机 + 虚拟板 QEMU）。

## 范围（关键取舍）
- 先**只做 Jetson（TensorRT）**，把"模型 → 设备"做到极致；
- 再用**一个**第二目标（如 RK3588/RKNN，或 QEMU 虚拟板）证明**可移植**，不要一开始铺很多板子；
- "支持越多板子"是陷阱：多样性的维护成本会吃掉所有时间。

## 客户与内容
- 客户：硬件/AI 创业公司、边缘 AI 产品团队、系统集成商（"我的模型上不了板/不稳/不能升级"）。
- 内容主线：**「从模型到设备」**——ONNX → TensorRT → systemd → OTA → 基准，和视频计划打通（GitHub/YouTube/抖音）。

## 风险
- JetPack 已覆盖不少 → 必须在**精简、可复现、跨板、部署流水线**上做出明确增量；
- 硬件多样性的成本 → 用运行时抽象 + 少量目标控制；
- "发行版"听起来偏底层 → 对外表达为 **"edge AI deployment platform built on a minimal Linux distro"**。

## 对外一句话
- **EN**：Build the image, drop in your model, ship it — a minimal, reproducible embedded Linux distro for deploying AI models at the edge.
- **ZH**：构建镜像、放入模型、交付上线 —— 一个精简、可复现、面向边缘 AI 模型部署的嵌入式 Linux 发行版。
