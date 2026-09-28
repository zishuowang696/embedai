# AGENTS.md

EmbedAI — a **hardware-centric** edge AI distro: get AI models running **stably and with high performance** on a specific board (first target: NVIDIA Jetson Orin Nano DevKit NVMe). Positioning: `docs/12-positioning.md`. The Yocto/OpenEmbedded build is managed with **KAS**. All interaction goes through `kas ... kas.yml`; there is no docker, builds run on the host (x86_64 Ubuntu, Python 3.10). The project README (Chinese) is accurate — read it for background.

## Commands (from repo root)
- `kas build kas.yml` — build the `embedai-image` target
- `kas build kas.yml:local/kas-lowmem.yml` — low-memory host overlay (`BB_NUMBER_THREADS=2`, `PARALLEL_MAKE=-j2`; swapping hurts more than low parallelism). `local/` is gitignored.
- `kas checkout kas.yml` — sync upstream layer repos to pinned SHAs + regenerate `build/`; idempotent, only needs network on first clone
- `kas shell kas.yml` — bitbake env shell (then e.g. `bitbake -c cleanall embedai-image`)
- `kas dump kas.yml` — show final expanded config
- `scripts/pull-sstate.sh [machine|qemu]` — fetch CI sstate from a Release into `build/sstate-cache`
- First checkout/build writes `kas.lock`.

## Layout & ownership
- Only `meta-embedai/` is in-repo and versioned. `oe-core/`, `meta-tegra/`, `meta-tegra-community/`, `meta-oe/`, `meta-virtualization/`, `tegra-demo-distro/`, `bitbake/` are gitignored clones pinned to exact commits in `kas.yml`.
- Any new recipe/bbappend goes in `meta-embedai/`. Edits to upstream dirs are futile: `kas checkout --force-checkout` discards them.
- All repos form one coherent OE-core master snapshot (layer series `blacksail`, cf. `LAYERSERIES_COMPAT_*`). Bump pinned commits together, never one repo at a time.
- Config: `distro embedai`, `machine jetson-orin-nano-devkit-nvme`, target `embedai-image` (recipe `meta-embedai/recipes-core/images/embedai-image.bb`).

## Config editing
- `build/conf/*` is regenerated on every kas run — never edit it. Settings belong in `kas.yml`: layers under `repos:`/`layers:`, local vars in `local_conf_header`, bblayers header in `bblayers_conf_header`.
- kas 5.3 / config format 22 schema: repo `layers:` values are `<repo-path>/<layer-name>` keys with `prio`; `bitbake` must be declared with `layers: {'': disabled}`. The pre-5.3 `path`/`priority` keys are rejected.
- **Images that `require core-image-minimal.bb`**: add packages via `CORE_IMAGE_EXTRA_INSTALL +=` — `CORE_IMAGE_BASE_INSTALL` is **dead** for that recipe (it hardcodes `IMAGE_INSTALL = "packagegroup-core-boot ${CORE_IMAGE_EXTRA_INSTALL}"`).

## Trim & build-speed conventions (see `docs/04-trimming.md`)
- **Prefer image-level trimming** (no sstate invalidation, image-only re-sign): `IMAGE_INSTALL:remove`, `BAD_RECOMMENDATIONS`, `PACKAGE_EXCLUDE`, `MACHINE_EXTRA_RRECOMMENDS:remove`.
- **`MACHINE_EXTRA_RRECOMMENDS:remove` is the sweet spot for modules** (e.g. `nvidia-kernel-oot-cameras`, `nvidia-kernel-oot-canbus`): drops them from the build graph → **saves both build time and image size**, no distro change.
- **Changing `DISTRO_FEATURES`/`MACHINE_FEATURES` invalidates a large fraction of sstate** (CI cache too). Plan all feature edits at once; **once settled, stop touching it**.
- **RDEPENDS vs RRECOMMENDS**: `3g`/`nfc`/`bluetooth` arrive via `packagegroup-base-extended`'s **RDEPENDS** — image-level can only *not install* them (`PACKAGE_EXCLUDE`); they still get **built**. Only a feature change removes them from the graph.
- Current trims: `DISTRO_FEATURES:remove = "pam virtualization 3g nfc bluetooth nfs zeroconf debuginfod gobject-introspection-data"` (**keep** wifi/alsa/ptest/opengl); `USE_PREBUILT_OPTEE = "1"`; `CUDA_ARCHITECTURES = "87"` in the llama-cpp recipe.
- `BUILDHISTORY_FEATURES = "image"` + `INHERIT += "buildhistory"` → `installed-package-sizes.txt` for **data-driven** trimming.

## sstate & CI caching (Release, not Actions cache)
- GitHub Actions cache is capped at **10GB/repo**; the Yocto `sstate` cache is 15–40GB → it must live in **Releases** (per-asset <2GiB, ≤1000 assets, unlimited total).
- Design (`.github/workflows/{embedai,qemu-smoke}.yml`): upload `sstate-cache` as **1.9GB parts** named `sstate-<ID>.part-*` with `sstate-<ID>.SHA256SUMS`; an atomic **`LATEST`** pointer is flipped **after** the full set is up (interrupted uploads never lose the previous cache). Restore reads `LATEST`, verifies sha256, extracts into `build/sstate-cache`. Legacy `sstate.part-*` names are cleaned up.
- **Never `--clobber` a live sstate tag** — that is why the versioned scheme exists.
- **CI build step must not swallow real errors**: it tees the log and fails the job on `ERROR: Task … failed with exit code` / `ERROR: Logfile of failure stored in`; a 5.5h budget SIGINT (paused, resumable) is *not* a failure. Images >2GiB **cannot** be published to a Release — keep the image under 2GiB or split it.

## Distro sanity gotcha
- `meta-embedai/conf/distro/embedai.conf` does `require conf/distro/include/tegrademo.inc` (lives in tegra-demo-distro's meta-tegrademo) and inherits `tegra-support-sanity`; the layer's `LAYERDEPENDS = "core tegra tegrademo"` and `LAYERSERIES_COMPAT = "blacksail"` must stay true or bitbake refuses to parse.
- `REQUIRED_TD_BBLAYERS_CONF_VERSION = "embedai-7"` (embedai.conf) must equal `TD_BBLAYERS_CONF_VERSION = "embedai-7"` (kas.yml `bblayers_conf_header`). Drift breaks the tegra distro sanity class with `sanity_conf_read` undefined.

## Host / environment gotchas
- Host Python is **3.10**; upstream meta-tegra TF-A needs ≥3.11 (`datetime.UTC`). Worked around by `meta-embedai/recipes-bsp/arm-trusted-firmware/arm-trusted-firmware_%.bbappend`. Newer upstream code may hit the same wall.
- `kas.yml` `local_conf_header` still references a legacy read-only sstate mirror under `/home/admin/tegra/tegra-demo-distro/build/sstate-cache` (that directory has since been deleted; harmless, never matched — layer SHAs differ).
- `INHERIT += "rm_work"` deletes per-recipe work dirs; `BB_DISKMON_DIRS` halts builds on low disk (a disk-full kill can later corrupt `build/cache/hashserv.db` → `database disk image is malformed`; fix = move aside `hashserv.db` + `bb_unihashes.dat` and re-parse).
- **`pixman`/`cc1plus` memory**: 7GB hosts thrash; use `local/kas-lowmem.yml`. Diagnose with `free`, load vs cores, and `vmstat` `si/so`.

## Why the build is slow (measured, `bitbake -g`)
- The heavy natives are `rust-native` → `llvm-native`. Reverse-dependency graph: `tegra-bootfiles → tegra-eks-image → optee-nvsamples-native → (optee-l4t.inc) python3-cryptography-native → maturin/setuptools-rust → rust-native → llvm-native`. **`python3-cryptography` is Rust-based**, and Rust's backend is LLVM.
- `USE_PREBUILT_OPTEE = "1"` removes `optee-os`, but the **EKS branch's `optee-nvsamples-native` remains**, so rust/llvm still build **once** (then sstate).
- It is **not** OpenGL/mesa on Jetson (`mesa` is absent from the Jetson graph; it belongs to the qemu config).
- Find such pullers with `kas shell kas.yml -c "bitbake -g embedai-image"` then walk `build/task-depends.dot` **upstream**.

## Virtual board (QEMU)
- `kas-qemu.yml` overlays `kas.yml` (overrides only `machine` + `target`): `kas build kas.yml:kas-qemu.yml`.
- Machine: upstream standard `qemuarm64` (do **not** invent a custom machine name — it breaks `COMPATIBLE_MACHINE`/kernel BSP lookup). Image: `meta-embedai/recipes-core/images/embedai-qemu-image.bb`.
- **The qemu image now ships a CPU-only llama.cpp**: `llama-cpp` (CUDA auto-off when `MACHINE_FEATURES` lacks `cuda`), `llama-model-qwen` (Qwen2.5-0.5B Q2_K, `hf-mirror.com` fallback), `llama-demo`, and `llama-boot-demo` (a oneshot that runs one inference at boot, prints `LLAMA_BOOT_DEMO_BEGIN/END` + expects `EMBEDAI_OK`, then **powers off** so `runqemu` exits).
- Boot smoke: `kas shell kas.yml:kas-qemu.yml -c "runqemu qemuarm64 nographic snapshot"` (the `snapshot` option is **required** for the `.ext4.zst` rootfs). CI job: `.github/workflows/qemu-smoke.yml`; markers `QEMU_BOOT_OK`, `LLAMA_CPP_DEMO_OK`.
- Scope: no Jetson GPU/NPU — validates boot/systemd/network + the CPU inference path; uses TCG on x86 runners (slow, not for perf tests).

## Network & download (China / GFW)
- Direct GitHub and many upstream hosts are unreliable from CN. **Measure before bulk downloading** — don't guess.
- Speed test (single connection, 20MB range): `scripts/speedtest-github.sh [URL] [MB]`. Known-good proxies as of 2026-09: `https://ghproxy.net` (~1.2 MB/s), `https://gh-proxy.com` (~0.7, **no Range support — do not use for split downloads**), `https://ghfast.top` (~0.2). Single-connection speed multiplies with parallel connections (~6x at 6-way).
- Pull the prebuilt download cache with `scripts/pull-dl-cache.sh`; it supports mirrors, 6-way parallel and resume, then `sha256sum -c`. Stage dir must be on the same filesystem as the destination (`/` is small on this host; use `/home`).
- Yocto source fetches: prefer **bitbake mirrors** over proxying GitHub — e.g. `KERNELORG_MIRROR` → USTC, huggingface → `hf-mirror.com` (`PREMIRRORS:prepend`). See `docs/07-local-build.md`, `docs/10-github-mirrors.md`.
- Release-cache design: `fetch-cache.yml` runs `bitbake --runall=fetch` on a runner, tars `downloads/` into `<2GiB` parts, uploads to the `dl-cache` release. Local pull → `BB_NO_NETWORK=1 kas build kas.yml`.
- When adding a mirror/proxy or a new download path, **record the measured speed and date** in `docs/10-github-mirrors.md`.
