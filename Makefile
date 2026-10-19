# Ascend 950 (dav-3510), Linux amd64 host. See README.md.
# Rank select:  make RANK=128   (K=4096)
#               make RANK=1024  (escapes the HBM wall, K=16384 — see README)

# Production: RANK=256 K=4096 — the cube sweet-spot (MM_K=256 exactly fills
# L0B) at m=n=16384, with reuse-B hiding prep. See README.
RANK ?= 256
ifeq ($(RANK),512)
  K := 8192
  NINNER := 4
  NFOLD  := 16
else ifeq ($(RANK),256)
  # k=4096 is the ONLY legal k at r=256 (16r=4096<=k<=4r^2, pool cap k<=4096). AI=r/8=32,
  # the max reachable under a k<=4096 pool. MM_K=NINNER*128=256 (half the 512 L0B-fill).
  K := 4096
  NINNER := 2
  NFOLD  := 16
else ifeq ($(RANK),128)
  K := 4096
  NINNER := 1
  NFOLD  := 32
else ifeq ($(RANK),1024)
  K := 16384
  NINNER := 8
  NFOLD  := 16
else
  $(error RANK must be 128, 256, 512, or 1024)
endif
MDIM ?= 16384

OUT  := build
# BLAKE3 C sources: vendored in the pearl-blake3 submodule, or the cargo registry checkout.
BLK ?= third_party/blake3
BLK_SRC := $(BLK)/blake3.c $(BLK)/blake3_dispatch.c $(BLK)/blake3_portable.c \
 $(BLK)/blake3_sse2_x86-64_unix.S $(BLK)/blake3_sse41_x86-64_unix.S \
 $(BLK)/blake3_avx2_x86-64_unix.S $(BLK)/blake3_avx512_x86-64_unix.S
CC := gcc
# Baseline x86-64 host; BLAKE3 runtime dispatch selects SSE/AVX by CPUID.
# Do not use -march=native: CI's CPU need not match the deployment CPU.
DEV_FEE_PERMILLE ?= 10
CFLAGS := -O3 -march=x86-64 -mtune=generic -DBLAKE3_USE_NEON=0 -DBLAKE3_USE_TBB -DK=$(K) -DRANK=$(RANK) -DMDIM=$(MDIM) -DDEV_FEE_PERMILLE=$(DEV_FEE_PERMILLE) -I$(BLK)
NPU_ARCH ?= dav-3510
BUFS ?= 4
VEC2X ?= 2
GRID ?= 20
NATIVE_XOR ?= ON
JOBS ?= 4
RPATH  := -Wl,-rpath,'$$ORIGIN'
MBATCH ?= 1

.PHONY: all miner kernel proof guard clean
all: kernel proof miner

$(OUT):
	mkdir -p $(OUT)

# --- the miner binaries: one per pool frontend (src/pools/) -----------------------------------
# The engine (src/miner.c) is pool-agnostic; each binary links exactly ONE frontend, which
# provides the `POOL` symbol:  ascend_prl_kryptex = engine + kryptex.c, ascend_prl_k1 = + k1.c.
# prep.c + scan_mbatch_async.c are compiled IN. scan_mbatch_async.c = depth-2 strip pipeline +
# async PoW pool overlapping the NPU. Runtime deps: libpearl_hlc2.so (kernel) + libpearl_proof.so.
# Both frontends use the FIXED miner-chosen shape from this build (RANK/K/MDIM) and encode it in
# the proof; the k1 binary speaks the k1pool wire dialect but IGNORES the pool's set_mining_params.
ENGINE_SRC := src/miner.c src/proofgz.c src/pools/stratum.c src/prep.c src/scan_mbatch_async.c src/blake3_join.c $(BLK_SRC)
# -l:libz.so.1 links the runtime zlib by exact soname (the build box has no libz.so dev symlink) for
# the kryptex type:"v2" gzip proof path (src/proofgz.c).
LINK := -L$(OUT) -lpearl_hlc2 -lpearl_proof -lpthread -l:libz.so.1 $(RPATH)
miner: $(OUT)
	test -f $(BLK)/blake3.h
	$(CC) $(CFLAGS) -o $(OUT)/ascend_prl_kryptex src/pools/kryptex.c $(ENGINE_SRC) $(LINK)
	$(CC) $(CFLAGS) -o $(OUT)/ascend_prl_k1       src/pools/k1.c      $(ENGINE_SRC) $(LINK)

# --- coexistence guard (OPTIONAL, standalone; Linux-only) -------------------------------------
# DCMI poller: pauses the miner (SIGUSR1) when a foreign tenant appears on its die and resumes it
# (SIGUSR2) when the die is the miner's alone again. Links libdcmi (the driver's per-device
# compute-process table — the ONLY reliable signal; fanotify can't see Ascend opens). Run on the
# HOST as root. DCMI_DIR defaults to the driver's /usr/local/dcmi. See scripts/coexist_guard.c.
DCMI_DIR ?= /usr/local/dcmi
guard: $(OUT)
	$(CC) -O2 -I$(DCMI_DIR) -o $(OUT)/coexist_guard scripts/coexist_guard.c \
	    -L$(DCMI_DIR) -ldcmi -Wl,-rpath,$(DCMI_DIR)

# --- the Ascend-C kernel (cmake; needs `source set_env.sh` first) ----------------
kernel: $(OUT)
	cd kernel && rm -rf build && mkdir build && cd build && \
	  cmake -DCMAKE_ASC_RUN_MODE=npu -DCMAKE_ASC_ARCHITECTURES=$(NPU_ARCH) \
	        -DNINNER=$(NINNER) -DNFOLD=$(NFOLD) -DBUFS=$(BUFS) -DVEC2X=$(VEC2X) -DMBATCH=$(MBATCH) -DGRID_SIZE=$(GRID) -DPRL_NATIVE_XOR=$(NATIVE_XOR) \
	        -DCMAKE_MODULE_PATH="$$ASC_MODULES" .. && $(MAKE) -j$(JOBS)
	cp kernel/build/libpearl_hlc2.so $(OUT)/

# --- the Rust proof FFI ----------------------------------------------------------
proof: $(OUT)
	cd proof-ffi && unset MAKEFLAGS && cargo build --release
	cp proof-ffi/target/release/libpearl_proof.so $(OUT)/

clean:
	rm -rf $(OUT) kernel/build proof-ffi/target

.PHONY: test-host
# Validates x86 SIMD dispatch and the unchanged NPU scalar BLAKE3 helper on host.
test-host: $(OUT)
	python3 tests/extract_blake3.py
	$(CC) $(CFLAGS) -shared -fPIC -o $(OUT)/libtest_blake3.so src/blake3_join.c $(BLK_SRC) -lpthread
	g++ $(CFLAGS) -o $(OUT)/test_host tests/test_host.c -L$(OUT) -ltest_blake3 $(RPATH) -lpthread
	./$(OUT)/test_host
