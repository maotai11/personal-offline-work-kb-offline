# AUTOCOPOLIOT 開發目標（KB-Guardian）

## 任務目標
完成離線可執行的 KB-Guardian，支援：
- F1 自動備份
- F2 防誤刪（大量刪除警示）
- F3 一鍵匯出（Pandoc）
- F4 Launcher（Logseq/OBS/備份/匯出/還原）
- F5 複習提醒（第二階段）

## 批次規則
- 每一批只改指定檔案。
- 每一批必提供：修改摘要、驗證方式、風險點。
- 每一批結尾必輸出：

[AUTOPILOT_STATUS]
status: CONTINUE|DONE|BLOCKED
next_prompt: <single-line next step>
summary: <single-line verified result>
[/AUTOPILOT_STATUS]
