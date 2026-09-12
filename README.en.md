# EmbedAI — Jetson AI Gateway

[中文](README.md) | English

[![build](https://github.com/zishuowang696/embedai/actions/workflows/embedai.yml/badge.svg)](https://github.com/zishuowang696/embedai/actions/workflows/embedai.yml)
![license](https://img.shields.io/badge/license-MIT-blue.svg)
![platform](https://img.shields.io/badge/platform-Jetson%20Orin%20Nano%20Super-76b900.svg)

Trimmed Tegra, leaving the maximum resources to AI.

## What this is

An **AI gateway** built on NVIDIA Jetson (Orin Nano **Super** DevKit, NVMe):

- **Minimal system**: no GUI, no desktop stack — only SSH for management.
- **Custom distro & image**: `embedai` / `embedai-image`.
- **Resources reserved for AI**: GPU/CUDA compute kept, everything else trimmed.

> Full documentation lives in [docs/](docs/README.md) (hardware, KAS, kernel, trimming, CI, gotchas).

## Build system: KAS

This repository manages the entire Yocto build with [KAS](https://kas.readthedocs.io/), replacing the `tegra-demo-distro` git-submodule approach.

```
~/tegra-kas/
├── kas.yml                      # KAS config: repos + layers + distro/machine/target
├── meta-embedai/                 # our own layer
│   ├── conf/
│   │   ├── layer.conf
│   │   └── distro/embedai.conf   # custom distro
│   ├── recipes-core/images/
│   │   └── embedai-image.bb      # custom minimal image
│   └── recipes-bsp/arm-trusted-firmware/
│       └── arm-trusted-firmware_%.bbappend   # Python 3.10 compatibility patch
└── build/                       # kas-generated build dir (not committed)
```

### Requirements

- `kas` 5.3+ (`pip install kas`)
- Disk: building a Jetson image needs roughly ~60 GB+ (old caches can be reused)

### Quick start

```bash
kas checkout kas.yml      # fetch and pin all layers
kas build kas.yml         # build embedai-image
kas shell kas.yml         # enter the bitbake environment
kas dump kas.yml          # print the fully-resolved config
```

The first build generates `kas.lock`, pinning every repository version.

### Reusing an old build cache (read-only mirror, no copying)

Artifacts from a previous build (`tegra-demo-distro/build/`) can be reused as a read-only source, so you don't need to copy tens of GB when disk is tight:

```
DL_DIR ?= "/old/path/build/downloads"                        # source packages (same pinned versions -> full hit)
SSTATE_DIR ?= "${TOPDIR}/sstate-cache"                       # your new local cache
SSTATE_MIRRORS = "file://.* file:///old/path/build/sstate-cache/PATH"  # read-only mirror of build artifacts
```

## Gotchas already solved

| Problem | Cause | Fix |
|---------|-------|-----|
| KAS 5.3 `layers` schema error | newer versions dropped `path`/`priority` | use `<repo.path>/<layer>` + `prio`; bitbake needs `layers: {'': disabled}` |
| `tegra_distro_update_bblayersconf` crash (`sanity_conf_read` undefined) | update path only runs on version mismatch | add `TD_BBLAYERS_CONF_VERSION = "embedai-7"` to `bblayers_conf_header` |
| GitHub clone timeouts | unstable network | pre-seed the repo directory from an existing local clone; kas skips if present |
| `ImportError: cannot import name 'UTC' from 'datetime'` | meta-tegra's TF-A recipe needs Python 3.11+, host has 3.10 | equivalent `timezone.utc` replacement via a bbappend in `meta-embedai` |

## Roadmap (trimming checklist)

- [ ] Confirm the real meta-tegra package names, then add AI packages to `embedai-image.bb`: `cudnn`, `tensorrt-core`, `tegra-libraries-cuda`, etc.
- [ ] Build an `ollama` recipe (native ARM64 deployment, no Docker).
- [ ] Drop unneeded `pam` / `virtualization` distro features (toggle comments in `embedai.conf`).
- [ ] Once builds pass, delete old `build/tmp` and `build/cache` to reclaim space.

## License

MIT
