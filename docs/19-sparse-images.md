# 19 · 稀疏镜像：为什么 14GB 的镜像其实只有 1GB

> 现象：CI 里 Jetson 镜像 `.ext4` 显示 **14336 MiB（14GB）**，直接上传超了 Release 单文件 2GiB 上限；而另一个 `tegraflash-tar.zst` 只有 **1.3GB**。
> 原因：前者是**稀疏文件（sparse file）**——"逻辑很大，物理很小"。本文讲清**怎么检测、怎么压缩**。

## 一、什么是稀疏文件

稀疏文件里有大量"空洞（hole）"：**逻辑上占用很大，但全是 0 的区间不分配实际磁盘块**。

关键区别——**逻辑大小 ≠ 物理占用**：

| 工具 | 你看的是 |
|---|---|
| `ls -l` / `stat -c %s` | **逻辑**大小（含空洞） |
| `du` / `stat -c %b` | **物理**占用（真正的块；`%b × 512` 字节） |

## 二、为什么 Yocto 镜像这么"稀释"

Yocto 的 `ext4` 镜像按 **`ROOTFS_SIZE`**（分区/文件系统目标大小）**预分配**，再把实际内容写进去——**没写满的部分就是空洞**。
所以"14GB 的 ext4"里，**真正有数据的可能只有几百 MB**，其余是 0。

相关变量：`IMAGE_ROOTFS_SIZE`、`IMAGE_OVERHEAD_FACTOR`、`IMAGE_ROOTFS_EXTRA_SPACE`。

## 三、怎么"检测"（判断是不是稀疏、空洞有多少）

```bash
ls -lh img.ext4          # 逻辑大小（14G）
du  -h img.ext4          # 物理占用（可能只有几百 M ← 说明稀疏）
du  -h --apparent-size img.ext4   # 再按逻辑算一遍（对比用）
stat -c 'size=%s  blocks=%b' img.ext4   # 物理 = %b × 512
filefrag -v img.ext4     # 逐段列出 extent / hole（看空洞分布）
```

**判据**：`du`（物理）**远小于** `ls`（逻辑）→ 就是稀疏。

> 更专业：`bmaptool create img.ext4 -o img.ext4.bmap` 生成 **块映射（哪些块非空）**，既用于检测，也用于"只写非空块"的快速刷机。

## 四、怎么"压缩"

**两种思路：**

**1) 直接压（简单，但慢）**
```bash
zstd img.ext4        # gzip/xz 同理
```
- 0 的压缩率极高 → 14GB 能压到 ~1GB；
- 缺点：压缩器要**读完整 14GB 的零**，慢。

**2) 稀疏感知（推荐）**
```bash
tar --sparse -cf - img.ext4 | zstd   # tar 直接跳过空洞，再压 → 快
zstd --sparse img.ext4               # zstd 自带稀疏支持
cp --sparse=always a b               # 本地复制保留稀疏
rsync -S a b                         # rsync 保留稀疏
```
**3) 刷机最专业：`bmaptool`**
```bash
bmaptool create img.ext4 -o img.ext4.bmap   # 生成块映射
bmaptool copy   img.ext4 /dev/sdX           # 只写非空块（快、还可校验）
```

## 五、CI / 发布的最佳实践

1. **别发"裸稀疏 ext4"**——它又大又空，还会卡 Release 的 2GiB 上限；
2. 发**压缩产物**：
   - `*.tegraflash.tar.zst`（真正的刷机包，已压缩，本例 1.3GB）；
   - 或额外的 `ext4.zst` / `ext4.gz`；
   - 附 `*.bmap` 供检测/快速刷机；
3. **若必须发裸镜像**：先 `zstd` 再发——大概率 <2GiB，**不用分卷**；
4. 需要"分卷"时，才是最后手段（如我们给 14GB 的裸 ext4 分了 8 卷——不划算）。

> 在本项目里：`meta-tegra/conf/machine/include/tegra-common.inc` 已有
> `IMAGE_FSTYPES += "tegraflash-tar.zst"`，所以**刷机包本来就是压缩的**；真正"胖"的只有裸 `.ext4`。

## 六、一句话

**稀疏镜像 = "逻辑大、物理小"**：
- **检测**：`du`（物理）vs `ls`/`stat`（逻辑），或 `filefrag -v`、`bmaptool create`；
- **压缩**：`zstd` 直压最省事，`tar --sparse`/`zstd --sparse` 更快，`bmaptool` 最专业（还能只写非空块）；
- **发布**：发**压缩产物 + `.bmap`**，别发裸稀疏 `.ext4`。
