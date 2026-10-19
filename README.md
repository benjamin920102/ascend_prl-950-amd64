# ascend_prl — Ascend 950 / Linux amd64 port

Source port of the supplied `ascend_prl-main(6).zip`. Target: Ascend 950PR/950DT
(`dav-3510`) with an x86-64 Linux host. This is not a prebuilt binary release.

## Changes

- CPU BLAKE3 1.8.2 C and assembly sources are included. NEON is disabled; SSE2,
  SSE4.1, AVX2 and AVX-512 are selected at runtime by the upstream dispatcher.
  No `-march=native`, so builds are not tied to the CI machine's CPU.
- Kernel defaults to `dav-3510`. Fold uses 950 `AscendC::BitwiseXor` by default.
  Staging protects in-place fold operations because this API forbids source/dest
  overlap. `NATIVE_XOR=OFF` selects the original four-op implementation for comparison.
  This conservative implementation retains a staging copy and barriers; no speedup
  is claimed. Scalar BLAKE3 remains on the AI Core scalar unit.
- Rust proof dependencies use relative paths and a pinned Pearl revision.
- CANN discovery works with x86_64 installations instead of an aarch64-only path.
- The original developer fee remains at 1% (`DEV_FEE_PERMILLE=10`).

## GitHub Actions

Unzip and push the CONTENTS of this directory to the root of a GitHub repository,
including `.github/workflows/build-950-amd64.yml`. Push, pull request, or manually
run **Build Ascend 950 amd64**. No NPU is needed for the compilation job.

The workflow:
1. Downloads and caches your exact CANN toolkit URL:
   https://ascend.devcloud.huaweicloud.com/artifactory/cann-run-mirror/software/legacy/20260422000325096/Ascend-cann-toolkit_9.0.0_linux-x86_64.run
2. Installs CANN 9.0.0 toolkit and the matching public 950 ops package.
3. Installs Rust stable and fetches the pinned Pearl source dependency.
4. Runs host BLAKE3 tests; compiles kernels, proof FFI and both miner frontends.
5. Uploads `ascend_prl-950-linux-amd64` as an Actions artifact containing a tarball
   and SHA256SUMS. It does not create a public release or start mining.

Optional repository variables `CANN_TOOLKIT_SHA256` and `CANN_OPS_SHA256` enforce
publisher checksums, if you have them. The installer also runs the `.run` integrity
check, rejects HTTP failures, and prints the downloaded SHA256. A checksum printed
by the job is a record, not independent publisher authentication. A failed download,
installer, test, or compilation fails the job rather than uploading partial binaries.
Do not commit installer packages or build outputs to git.

## Local build

Ubuntu 22.04 x86-64: install build-essential, cmake, git, curl, file, zlib1g-dev,
pkg-config, libssl-dev, clang, libclang-dev, python3-dev, python3-pip, numactl and
Rust stable. Python SDK dependencies are listed in the workflow.

```bash
sudo bash scripts/install_cann.sh  # toolkit + 950 ops, no driver
bash scripts/build.sh
```

For a nonstandard CANN location:

```bash
CANN_ENV=/your/Ascend/ascend-toolkit/set_env.sh bash scripts/build.sh
```

Compile settings (defaults): `RANK=256`, `NPU_ARCH=dav-3510`, `BUFS=4`, `VEC2X=2`,
`GRID=20`, `MBATCH=1`, `NATIVE_XOR=ON`, `JOBS=4`. GRID is deliberately conservative,
not an assertion that every 950 has 20 cores. Verify the target SKU has at least
GRID Cube cores and GRID*VEC2X Vector cores. BUFS must remain divisible by VEC2X.

```bash
source scripts/env.sh
make test-host
make kernel NATIVE_XOR=OFF  # optional comparison build, not automatic fallback
```

## Verify on 950 before mining

The target host needs a compatible 950 driver and CANN runtime/ops installation.
GitHub's standard runner cannot validate device behavior or hashrate.

```bash
source scripts/env.sh
python3 -m pip install numpy
# Requires default RANK=256 / MBATCH=1; validates exact integer GEMM and fold.
timeout 180s python3 tests/smoke_950.py
```

Run the smoke test with native XOR ON and OFF. The test compares every transcript
word against a CPU reference over two strips and exercises flag/buffer reuse. It
uses target=0 and does not submit shares. It does not independently verify the
on-device hash output or pool acceptance. Host tests separately compare the exact
scalar BLAKE3 helper against upstream BLAKE3 and the SIMD implementation against
portable C over 1000 vectors, plus serial/threaded hashing of 4 MiB.

Then configure your pool and wallet:

```bash
export WALLET=prl1_your_wallet
export POOL=your.pool.host PORT=7000
ASCEND_RT_VISIBLE_DEVICES=0 bash scripts/launch.sh
```

NUMA placement remains supported. Do not use the upstream ARM Docker image with
these x86-64 binaries; build/deploy on your amd64 CANN environment. Old upstream
release binaries are also not this port.

## Validation status

Locally validated: x86-64 host build/tests and shell/YAML syntax. The CANN toolkit
and 950 hardware are not installed in the authoring environment, so the full
CANN/Rust build, 950 kernel launch, actual SIMD lowering, pool acceptance and
performance remain unverified. The included Actions job is the full compile check;
its success must be confirmed in your repository. Existing matmul APIs and the
Cube/Vector GM-flag pipeline are retained, and may require SDK-specific adjustment
if your 950 CANN build differs. This is a source port for testing, not a claim of
hardware-tested production support.

## References

- Native XOR support: https://asc.gitcode.com/api/SIMD-API/c_api/reg_compute/reg_logic/asc_xor.html
- BitwiseXor interface/alias constraint: https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/900/API/ascendcopapi/atlasascendc_api_07_10273.html
- CANN 9 installation: https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/900/softwareinst/instg/instg_0008.html
- BLAKE3: https://github.com/BLAKE3-team/BLAKE3/tree/1.8.2
- Pearl: https://github.com/pearl-research-labs/pearl
