# KB-Guardian (Personal Offline Work KB)

離線個人知識管理啟動器（會計事務所個人版）。

## 目標
- 離線可用（目標機不需 npm/pip）
- 單一入口啟動 Logseq/OBS
- 啟動前自動備份 KB
- 一鍵匯出 SOP（Pandoc）
- 還原備份

## 快速啟動（開發機）
1. `python -m venv .venv`
2. `.venv\\Scripts\\activate`
3. `pip install -r requirements.txt`
4. `python -m kb_guardian.main`

## 打包（開發機）
`pyinstaller --onedir --windowed --name kb-guardian --add-data "config.ini;." kb_guardian/main.py`

## 目標機
僅放置 `dist/kb-guardian/`，不需安裝 Python。

## Auto-Copilot（無人值守）
執行下列任一方式可自動完成 build + smoke + 離線包打包 + checkpoint：

1. 雙擊 `AUTO_COPILOT.bat`
2. PowerShell：
   `powershell -ExecutionPolicy Bypass -File .\scripts\run_autocopilot.ps1`

每批會寫入節點檔至 `autopilot/checkpoints/`，可用於回溯。

## 產生離線交付包
`powershell -ExecutionPolicy Bypass -File .\scripts\make_offline_bundle.ps1 -Rebuild`

輸出位置：
- 目錄：`release/kb-guardian-offline-<timestamp>/`
- 壓縮檔：`release/kb-guardian-offline-<timestamp>.zip`
