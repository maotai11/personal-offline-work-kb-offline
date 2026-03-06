# KB-Guardian Releases

## v0.1.1 (2026-03-05)

### 修正內容
- Logseq、OBS、Pandoc 未安裝時，改顯示友善提示對話框（含預期路徑與下載連結），不再顯示原始錯誤訊息

### Build Info
- **Platform:** Linux x86_64
- **Python:** 3.12.3
- **PyInstaller:** 6.19.0
- **tkinter:** 8.6（已內建，無需額外安裝）

### Files
| File | Size | SHA256 |
|------|------|--------|
| `kb-guardian-linux-v0.1.1-20260305.zip` | 13 MB | `823502dc12dadea324590ef0fe3cb96131e092641c4c091843c1792f7f66ad4d` |

### Contents
```
dist/kb-guardian/
├── kb-guardian              # Linux 執行檔
└── _internal/
    ├── config.ini           # 預設設定
    ├── libtk8.6.so          # tkinter runtime (已內建)
    ├── _tk_data/            # Tk/Tcl 資料
    ├── libpython3.12.so.1.0
    └── ... (其他 runtime libraries)
```

### Windows 版本
Windows 執行檔透過 GitHub Actions 自動建置：
- 推送 `v*` tag → 自動觸發建置並建立 Release
- 在 GitHub Actions 頁面手動觸發 `workflow_dispatch`

參閱 `.github/workflows/build-release.yml`

### 注意事項
- Linux 版本：tkinter 已完整內建，**無需**另外安裝 `python3-tk`
- Windows 版本：`.exe` 需在 Windows 環境建置（詳見 GitHub Actions workflow）

---

## v0.1.0 (2026-03-05) _(已棄用)_
- 初始版本，tkinter 未內建，缺工具時顯示原始錯誤
