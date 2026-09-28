# 18 · SDK / eSDK / sstate：概念与选择

> 三个词经常混用，其实是**三样不同的东西**。一句话区分：
> **`sstate` 是"给构建机的缓存"，`SDK` 是"给开发者的工具链"，`eSDK` 是"把前两者打包，给系统开发者离线用"。**

## 对比

| | `sstate` | `SDK` | `eSDK`（可扩展 SDK） |
| --- | --- | --- | --- |
| 是什么 | **任务中间产物的缓存**（对象文件、sysroot、native 工具、rpm 包…） | 可安装的**交叉工具链 + 镜像的目标 sysroot**（头文件+库） | **SDK + 该镜像所需的 sstate 子集 + bitbake + devtool** |
| 给谁用 | **bitbake 自己** | **应用开发者** | **系统/发行版开发者** |
| 能干什么 | 跳过重编（命中即复用） | 交叉编译你的应用、链接镜像里的库 | **离线** `devtool modify/build`、改/加 recipe、重编 |
| 含 bitbake / devtool | ❌ | ❌ | ✅ |
| 能离线改构建 | ❌ | ❌ | ✅ |
| 典型体积 | **最大**（15–40GB） | 中（~1–3GB） | 大（SDK + sstate 子集，数 GB） |
| 怎么生成 | 每次构建自动写 | `bitbake <image> -c populate_sdk` | `bitbake <image> -c populate_sdk_ext` |

## 三者关系（不是简单的"子集"）

- **`sstate`**：内容寻址的缓存，本质是"原料仓库"——**不是给人用的成品**，是一堆哈希目录。
- **`SDK`**：从镜像的 sysroot 打包出的**成品工具链**——拿到别的机器装完就能编应用。**它不含构建系统**。
- **`eSDK`**：在 SDK 基础上**塞进该镜像所需的 `sstate` 子集 + bitbake 元数据 + devtool** → 于是**离线也能改 recipe、重编**。

> 类比：`sstate` = 车间仓库；`SDK` = 一套精巧工具；`eSDK` = **带料的工具箱**（工具 + 够用的原料 + 说明）。

## 怎么选

| 场景 | 用什么 |
| --- | --- |
| 本地**已有构建树**、只改单个 recipe | **`sstate` + `devtool`**（最轻） |
| 只想**交叉编个应用**、链接镜像里的库 | **`SDK`** |
| 本地**不想跑全量**、要**离线**改 recipe/加包 | **`eSDK`** |
| 换新机器 / 无网环境做开发 | **`eSDK`** |

## 我们的 eSDK 工作流

- **CI**：`.github/workflows/esdk.yml`（**手动触发**）
  `checkout → free disk → 装依赖 → 生成 kas-ci.yml → restore sstate → kas checkout → populate_sdk_ext → 分卷 <2GiB 发布到 Release `esdk-latest`（版本化 + `LATEST`，不覆盖）`
- **配置**：`kas-esdk.yml`（`INHERIT += "populate_sdk_ext"`）。
- **本地**：
  ```bash
  cat esdk-*.part-* > esdk.sh && sh esdk.sh
  source <安装目录>/environment-setup-*
  devtool modify <recipe> && devtool build <recipe>   # 离线、分钟级
  ```

## 注意

- **体积大** → 必须分卷（Release 单文件 <2GiB）；慢网下载慢（和 sstate 同病）。
- **配置必须与目标一致**（distro/machine）。我们改过 `DISTRO_FEATURES` → eSDK 必须对应**最终**配置。
- 带 CUDA 的镜像，sstate 子集可能把 `gcc-for-nvcc`/`llvm` 之类也带进去 → 更大。
- eSDK 的元数据是**快照**：**加新 layer / 大改配置**仍需回 CI 重出。

## 与整体路线的关系

**原则：CI 编全量 → 本地只做增量。** 本地两条路径：

1. **构建树 + `pull-sstate.sh` + `devtool`**（轻，需本地有一份 sstate）；
2. **装 eSDK**（重一次，之后**完全离线**，不依赖构建树/网络）。
