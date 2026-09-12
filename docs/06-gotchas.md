# 06 · 环境与踩坑

## 宿主环境

- 宿主机：Ubuntu x86_64，**Python 3.10**
- 工具：`kas` 5.3（`pip install kas`），构建直接跑在宿主机，不用 docker
- 磁盘：完整 Jetson 编译约需 **60G+**

## 坑位清单

### 1. Python 3.10 vs TF-A（`datetime.UTC`）

meta-tegra 的 `arm-trusted-firmware` 用到 Python 3.11+ 的 `datetime.UTC`，宿主 3.10 会报
`ImportError: cannot import name 'UTC' from 'datetime'`。

已由 `meta-embedai/recipes-bsp/arm-trusted-firmware/arm-trusted-firmware_%.bbappend` 用 `timezone.utc` 等价替换修复。**升级 meta-tegra 时留意同类问题**，先怀疑 Python 版本要求。

### 2. 本机硬编码路径

`kas.yml` 的 `local_conf_header` 里 `DL_DIR`、`SSTATE_MIRRORS` 指向
`/home/admin/tegra/tegra-demo-distro/build/`（一台旧构建复用为只读缓存）。

- 只在这台机器上有效，且仅当上游 SHA 一致时才命中
- CI 里通过 sed 生成 `kas-ci.yml` 把这两个路径中和掉

### 3. KAS 5.3 / config format 22 schema

- repo 的 `layers:` 键是 `<repo-path>/<layer-name>`，值用 `prio`
- `bitbake` 必须声明为 `layers: {'': disabled}`
- 旧的 `path` / `priority` 键会被拒绝

### 4. distro sanity 版本串必须一致

- `embedai.conf` 的 `REQUIRED_TD_BBLAYERS_CONF_VERSION = "embedai-7"`
- 必须等于 `kas.yml` `bblayers_conf_header` 里的 `TD_BBLAYERS_CONF_VERSION = "embedai-7"`

不一致会触发 `tegra_distro_update_bblayersconf` 并因找不到模板而崩溃（`sanity_conf_read` 未定义）。

### 5. 内核默认是 `linux-yocto`

上游 `tegrademo.inc` 主动设的，不是 KAS 问题——详见 [03 · 内核选择](03-kernel.md)。

### 6. `build/conf/*` 每次 kas 运行都会重写

不要直接改 `build/conf/local.conf` / `bblayers.conf`；设置写进 `kas.yml`。

## 常用命令

```bash
kas build kas.yml                 # 构建 embedai-image
kas checkout kas.yml              # 同步层到锁定 commit + 重建 build/
kas shell kas.yml                 # bitbake 环境
kas dump kas.yml                  # 查看展开后的配置
kas shell kas.yml -c "bitbake -p" # 只解析，验证配置
```
