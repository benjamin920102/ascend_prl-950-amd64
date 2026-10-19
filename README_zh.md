# Ascend 950 / amd64 移植版

以提供的 `ascend_prl-main(6).zip` 為基礎，目標為 Ascend 950PR/950DT + Linux x86-64 主機。

- Host BLAKE3 改為 x86 SSE2／SSE4.1／AVX2／AVX-512 runtime dispatch，關閉 NEON。
- NPU 編譯目標為 `dav-3510`，fold 預設使用 `BitwiseXor`；有暫存 copy 以避免 API 禁止的來源／目的重疊，未宣稱效能提升。
- `NATIVE_XOR=OFF` 可切回原本四操作實作比較。
- Rust proof 依賴改為相對路徑，腳本下載固定 commit。
- 原本 1% developer fee 保留。

把解壓縮後資料夾內的內容放到 GitHub repo 根目錄，務必包含 `.github`。
Push 後 Actions 會自動下載指定的 CANN 9.0.0 x86-64 toolkit，安裝匹配的 950 ops，
執行 host 測試、編譯並上傳 binary artifact。不會自動啟動挖礦或公開 release。

本機建置：

```bash
sudo bash scripts/install_cann.sh
bash scripts/build.sh
```

950 硬體驗證（預設 RANK=256 / MBATCH=1）：

```bash
source scripts/env.sh
python3 -m pip install numpy
timeout 180s python3 tests/smoke_950.py
```

驗證通過後：

```bash
export WALLET=prl1_your_wallet
export POOL=your.pool.host PORT=7000
ASCEND_RT_VISIBLE_DEVICES=0 bash scripts/launch.sh
```

本環境僅完成 amd64 host 測試與靜態檢查，沒有 CANN 或 950 硬體，完整編譯與 NPU 執行未驗證。
請先確認 Actions 編譯結果，再於 950 上跑 smoke test。這是待實機驗證的 source port，
不是已完成 950 實測的 binary。詳細設定、驗證範圍和限制見 README.md。
