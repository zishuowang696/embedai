# 09 · 查依赖：谁依赖了我的层 / 我依赖了谁

## 场景

你做了一个 Yocto/OpenEmbedded 层（如 `meta-TinyAi`，collection `embedlab`），有人开始依赖它。想查“谁、怎么依赖我的”。

## 先分清两种“依赖”

| 类型 | 机制 | 能否在 GitHub 上看到 |
|------|------|----------------------|
| **包管理生态**（npm / pip / go / cargo） | 清单文件（package.json、requirements.txt…） | ✅ GitHub 仓库页 **Insights → Dependency graph → Dependents**（“Used by”） |
| **Yocto 层** | `LAYERDEPENDS`、`bblayers.conf`、`kas.yml` | ❌ GitHub 不认，需要代码搜索/Layer Index |

Yocto 层属于第二种，GitHub 的 “Dependents” 帮不上忙。

## 别人依赖一个层，通常写在三处

1. 对方层的 `conf/layer.conf`：

   ```bb
   LAYERDEPENDS_their-layer = "core ... embedlab"   # 你的 collection 名
   ```

2. 对方的 `bblayers.conf`（或 KAS 生成的）：

   ```
   BBLAYERS += "/path/to/meta-TinyAi"
   ```

3. 对方的 `kas.yml`（用 KAS 时）：

   ```yaml
   repos:
     meta-TinyAi:
       url: https://github.com/zishuowang696/meta-TinyAi
       layers:
         '': {}
   ```

**关键点**：搜索时要找的是你的 **collection 名（`embedlab`）**、**层目录名（`meta-TinyAi`）** 或 **仓库 URL**，而不是仓库名本身。

## 怎么查

### 1. GitHub 代码搜索（最常用）

- **网页版**（推荐，功能最强）：
  - `https://github.com/search?q=%22embedlab%22+LAYERDEPENDS&type=code`
  - 或搜仓库地址：`https://github.com/search?q=zishuowang696%2Fmeta-TinyAi&type=code`
- **CLI/API**：

  ```bash
  gh api "search/code?q=%22embedlab%22+LAYERDEPENDS" \
    --jq '.items[] | "\(.repository.full_name)  \(.path)"'
  ```

  注意：代码搜索只索引默认分支、且范围有限；**0 结果不等于没人用**（对方可能是私有仓库，或写在本地未公开）。

### 2. OpenEmbedded Layer Index

若你的层登记在 <https://layers.openembedded.org>：

- 层详情页会列出它**依赖谁**；要反查“谁依赖我”，用它的 API 拉全部层再过滤 `LAYERDEPENDS`，或直接在网页按 collection 名搜。
- 未登记则查不到。

### 3. 构建内查层间依赖

在你自己的构建里：

```bash
kas shell kas.yml -c "bitbake-layers show-layers"
kas shell kas.yml -c "bitbake-layers show-cross-depends"
```

只能看**当前构建内**的层依赖，看不到外部使用者。

### 4. GitHub 其他线索

- **Fork / Star / Watchers**：常有人先 fork 再改。
- **Issues / PR / Discussions**：使用者常来报问题。
- 搜索 `bblayers.conf` / `kas.yml` 里出现你的仓库 URL（同 1 的代码搜索）。

## 本仓库实例（已试）

对 collection `embedlab` 做过 GitHub 代码搜索：

```bash
gh api "search/code?q=%22embedlab%22+LAYERDEPENDS" --jq '.total_count'
# => 0
```

即**目前没有公开仓库在 `LAYERDEPENDS` 里引用它**。若确实有人依赖，最可能是：对方是私有仓库、或在本地 `bblayers.conf`/`kas.yml` 里直接加路径（未提交公开）。

## 想主动“被找到”的建议

- 层仓库里放清晰的 `README`：写明 collection 名、依赖、如何在 `kas.yml`/`bblayers.conf` 引用。
- 需要外部可见时，把层登记到 Layer Index，并给仓库打 `yocto`/`openembedded` topics。
