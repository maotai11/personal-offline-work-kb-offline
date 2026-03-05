"""KB-Guardian smoke test。
驗證匯入、最小資料夾、備份流程，並輸出 OK token。
"""

from __future__ import annotations

import logging
import shutil
from datetime import datetime
from pathlib import Path

from kb_guardian.main import APP_VERSION, AppConfig, create_backup_archive, get_runtime_root


def main() -> int:
    project_root = get_runtime_root()
    smoke_root = project_root / ".smoke_workspace"
    smoke_root.mkdir(parents=True, exist_ok=True)

    cfg_ini = smoke_root / "config.ini"
    cfg_ini.write_text(
        "\n".join(
            [
                "[paths]",
                "kb_root = ./KB",
                "videos_dir = ./videos",
                "exports_dir = ./exports",
                "backups_dir = ./backups",
                "logseq_exe = ./tools/logseq-portable/Logseq.exe",
                "obs_exe = ./tools/obs-portable/bin/64bit/obs64.exe",
                "pandoc_exe = ./tools/pandoc/pandoc.exe",
                "",
                "[backup]",
                "max_backups = 30",
                "auto_backup_on_launch = true",
                "",
                "[protection]",
                "enable_delete_guard = false",
                "delete_threshold_count = 5",
                "delete_threshold_seconds = 60",
                "",
                "[review]",
                "enable_review_reminder = true",
                "default_review_days = 14",
                "",
            ]
        ),
        encoding="utf-8",
    )

    cfg = AppConfig(smoke_root)
    log_dir = project_root / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger("kb_guardian_smoke")
    logger.setLevel(logging.INFO)
    if not logger.handlers:
        fh = logging.FileHandler(log_dir / "smoke.log", encoding="utf-8")
        fh.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
        logger.addHandler(fh)

    try:
        # 建立最小測試資料
        (cfg.kb_root / "pages").mkdir(parents=True, exist_ok=True)
        seed = cfg.kb_root / "pages" / "SOP｜SmokeTest.md"
        if not seed.exists():
            seed.write_text(
                "- # SOP｜SmokeTest\n  - 最後複習:: [[2025-01-01]]\n  - 複習週期:: 14天\n",
                encoding="utf-8",
            )

        backup = create_backup_archive(cfg.kb_root, cfg.backups_dir, cfg.max_backups, logger, prefix="KB_smoke")
        token = f"OK_TOKEN|{APP_VERSION}|{datetime.now().isoformat()}"
        logger.info(token)

        print(f"backup={backup}")
        print(token)
        return 0
    finally:
        shutil.rmtree(smoke_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
