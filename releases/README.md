# KB-Guardian Releases

## v0.1.0 (2026-03-05)

### Build Info
- **Platform:** Linux x86_64
- **Python:** 3.12.3
- **PyInstaller:** 6.19.0
- **tkinter:** 8.6 (已內建，無需額外安裝)
- **Build Command:** `pyinstaller --noconfirm --onedir --windowed --name kb-guardian --add-data "config.ini:." kb_guardian/main.py`

### Files
| File | Size | SHA256 |
|------|------|--------|
| `kb-guardian-linux-v0.1.0-20260305.zip` | 17 MB | `ba4f0041640eeb2ae0663d418e6c55c7ee160791e273539025fdef6a3387bd94` |

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
