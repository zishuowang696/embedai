# AGENTS.md

Yocto/OpenEmbedded build for a trimmed NVIDIA Jetson (Orin Nano DevKit NVMe) "AI gateway" image, managed with **KAS**. All interaction goes through `kas ... kas.yml`; there is no docker, builds run on the host (x86_64 Ubuntu, Python 3.10). The project README (Chinese) is accurate — read it for background.

## Commands (from repo root)
- `kas build kas.yml` — build the `embedai-image` target
- `kas checkout kas.yml` — sync upstream layer repos to pinned SHAs + regenerate `build/`; idempotent, only needs network on first clone
- `kas shell kas.yml` — bitbake env shell (then e.g. `bitbake -c cleanall embedai-image`)
- `kas dump kas.yml` — show final expanded config
- First checkout/build writes `kas.lock`.

## Layout & ownership
- Only `meta-embedai/` is in-repo and versioned. `oe-core/`, `meta-tegra/`, `meta-tegra-community/`, `meta-oe/`, `meta-virtualization/`, `tegra-demo-distro/`, `bitbake/` are gitignored clones pinned to exact commits in `kas.yml`.
- Any new recipe/bbappend goes in `meta-embedai/`. Edits to upstream dirs are futile: `kas checkout --force-checkout` discards them.
- All repos form one coherent OE-core master snapshot (layer series `blacksail`, cf. `LAYERSERIES_COMPAT_*`). Bump pinned commits together, never one repo at a time.
- Config: `distro embedai`, `machine jetson-orin-nano-devkit-nvme`, target `embedai-image` (recipe `meta-embedai/recipes-core/images/embedai-image.bb`).

## Config editing
- `build/conf/*` is regenerated on every kas run — never edit it. Settings belong in `kas.yml`: layers under `repos:`/`layers:`, local vars in `local_conf_header`, bblayers header in `bblayers_conf_header`.
- kas 5.3 / config format 22 schema: repo `layers:` values are `<repo-path>/<layer-name>` keys with `prio`; `bitbake` must be declared with `layers: {'': disabled}`. The pre-5.3 `path`/`priority` keys are rejected.

## Distro sanity gotcha
- `meta-embedai/conf/distro/embedai.conf` does `require conf/distro/include/tegrademo.inc` (lives in tegra-demo-distro's meta-tegrademo) and inherits `tegra-support-sanity`; the layer's `LAYERDEPENDS = "core tegra tegrademo"` and `LAYERSERIES_COMPAT = "blacksail"` must stay true or bitbake refuses to parse.
- `REQUIRED_TD_BBLAYERS_CONF_VERSION = "embedai-7"` (embedai.conf) must equal `TD_BBLAYERS_CONF_VERSION = "embedai-7"` (kas.yml `bblayers_conf_header`). Drift breaks the tegra distro sanity class with `sanity_conf_read` undefined.

## Host / environment gotchas
- Host Python is **3.10**; upstream meta-tegra TF-A needs ≥3.11 (`datetime.UTC`). This is worked around by `meta-embedai/recipes-bsp/arm-trusted-firmware/arm-trusted-firmware_%.bbappend`. Newer upstream code may hit the same wall — suspect Python-version requirements before debugging exotic errors.
- `kas.yml` `local_conf_header` hardcodes host-specific absolute paths: `DL_DIR` and `SSTATE_MIRRORS` point at `/home/admin/tegra/tegra-demo-distro/build/`, a prior full build reused as a read-only cache. Only valid on this machine and only hits when upstream SHAs match.
- `INHERIT += "rm_work"` deletes per-recipe work dirs; `BB_DISKMON_DIRS` halts builds on low disk. ~60G+ free is expected.
- AI packages (cudnn, tensorrt-core, tegra-libraries-cuda, …) are intentionally commented out in `embedai-image.bb`; confirm real package names in meta-tegra before enabling.
