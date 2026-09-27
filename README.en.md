# EmbedAI — an Embedded Distro for Edge AI

[中文](README.md) | English

[![build](https://github.com/zishuowang696/embedai/actions/workflows/embedai.yml/badge.svg)](https://github.com/zishuowang696/embedai/actions/workflows/embedai.yml)
![license](https://img.shields.io/badge/license-MIT-blue.svg)
![platform](https://img.shields.io/badge/platform-Jetson%20Orin%20Nano%20Super-76b900.svg)

Hardware first: get AI models running **stably and fast** on the board.

## What this is

A **hardware-centric** edge AI distro: we tune the whole stack for a specific board (currently NVIDIA Jetson Orin Nano **Super** DevKit, NVMe) so models run **stably and with high performance** (see [docs/12-positioning.md](docs/12-positioning.md)).

- **Minimal system**: no GUI, no desktop stack — only SSH for management.
- **Custom distro & image**: `embedai` / `embedai-image`.
- **Resources reserved for AI**: GPU/CUDA compute kept, everything else trimmed.
- **Pinned stack**: kernel / drivers / CUDA versions locked via KAS — identical on any machine and in CI.

> Full documentation lives in [docs/](docs/README.md) (hardware, KAS, kernel, trimming, CI, virtual board, download acceleration, positioning).

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

### CI cache: persist sstate in GitHub Releases (bypassing the 10GB Actions cap)

GitHub Actions cache is capped at **10GB per repo**, while this project's Yocto
`sstate` cache is 15–30GB — so `actions/cache` always exceeded the limit and the
save failed silently, forcing a **from-scratch rebuild on every run**.

We persist it in a **GitHub Release** instead (per-asset <2GiB, ≤1000 assets,
unlimited total size):

- compile artifacts are split into **1.9GB parts** and uploaded to Releases (`sstate-jetson` / `sstate-qemu`)
- **versioned, never overwritten**: the full set is uploaded first, then an atomic `LATEST` pointer is flipped — an interrupted upload never loses the previous cache
- restore reads `LATEST`, downloads that set, verifies with `sha256sum -c`, and extracts into `build/sstate-cache`
- a 15GB restore takes ~**3 min** inside CI

Local reuse (optional, mind your bandwidth):

```bash
scripts/pull-sstate.sh          # fetch sstate-jetson -> build/sstate-cache
scripts/pull-sstate.sh qemu     # fetch sstate-qemu (qemuarm64)
```

> Principle: **build everything in CI, rebuild only what changed locally.** See [docs/17-dev-loop.md](docs/17-dev-loop.md).

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
