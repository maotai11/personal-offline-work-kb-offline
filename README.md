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
