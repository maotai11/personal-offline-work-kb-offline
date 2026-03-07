"""KB-Guardian 主程式。
提供離線知識庫啟動、備份、防誤刪、匯出與還原功能。
"""

from __future__ import annotations

import configparser
import logging
import re
import shutil
import subprocess
import sys
import threading
import time
import zipfile
from collections import deque
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox

try:
    from watchdog.events import FileSystemEventHandler
    from watchdog.observers import Observer
    WATCHDOG_AVAILABLE = True
except Exception:
    FileSystemEventHandler = object  # type: ignore[assignment]
    Observer = object  # type: ignore[assignment]
    WATCHDOG_AVAILABLE = False

APP_NAME = "工作知識庫管理器"
APP_VERSION = "v0.1.0"


def get_runtime_root() -> Path:
    """取得執行根目錄（支援 PyInstaller 與原始碼執行）。"""
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parents[1]


def create_backup_archive(
    kb_root: Path,
    backups_dir: Path,
    max_backups: int,
    logger: logging.Logger,
    prefix: str = "KB_backup",
) -> Path:
    """建立 KB 壓縮備份並清理超量舊備份。"""
    if not kb_root.exists():
        raise FileNotFoundError(f"KB 路徑不存在：{kb_root}")

    backups_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    zip_path = backups_dir / f"{prefix}_{ts}.zip"
    logger.info("開始備份：%s", zip_path)

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for p in kb_root.rglob("*"):
            if p.is_file():
                zf.write(p, p.relative_to(kb_root.parent))

    backups = sorted(backups_dir.glob("KB_*.zip"), key=lambda p: p.stat().st_mtime, reverse=True)
    for old in backups[max_backups:]:
        try:
            old.unlink()
        except Exception:
            logger.exception("刪除舊備份失敗：%s", old)

    logger.info("備份完成：%s", zip_path)
    return zip_path


class AppConfig:
    """應用設定資料模型。"""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.config_path = root / "config.ini"
        if not self.config_path.exists():
            # PyInstaller frozen 模式下 datas 進入 _MEIPASS，先找旁邊再找 _MEIPASS
            example = root / "config.ini.example"
            if not example.exists():
                meipass = getattr(sys, "_MEIPASS", None)
                if meipass:
                    example = Path(meipass) / "config.ini.example"
            if example.exists():
                shutil.copy2(example, self.config_path)
        self.parser = configparser.ConfigParser()
        self.parser.read(self.config_path, encoding="utf-8-sig")

    def _p(self, section: str, key: str, default: str) -> Path:
        raw = self.parser.get(section, key, fallback=default)
        return (self.root / raw).resolve()

    @property
    def kb_root(self) -> Path:
        return self._p("paths", "kb_root", "../KB")

    @property
    def videos_dir(self) -> Path:
        return self._p("paths", "videos_dir", "../videos")

    @property
    def exports_dir(self) -> Path:
        return self._p("paths", "exports_dir", "../exports")

    @property
    def backups_dir(self) -> Path:
        return self._p("paths", "backups_dir", "../backups")

    @property
    def logseq_exe(self) -> Path:
        return self._p("paths", "logseq_exe", "../tools/logseq-portable/Logseq.exe")

    @property
    def obs_exe(self) -> Path:
        return self._p("paths", "obs_exe", "../tools/obs-portable/bin/64bit/obs64.exe")

    @property
    def pandoc_exe(self) -> Path:
        return self._p("paths", "pandoc_exe", "../tools/pandoc/pandoc.exe")

    @property
    def max_backups(self) -> int:
        return self.parser.getint("backup", "max_backups", fallback=30)

    @property
    def auto_backup_on_launch(self) -> bool:
        return self.parser.getboolean("backup", "auto_backup_on_launch", fallback=True)

    @property
    def enable_delete_guard(self) -> bool:
        return self.parser.getboolean("protection", "enable_delete_guard", fallback=True)

    @property
    def delete_threshold_count(self) -> int:
        return self.parser.getint("protection", "delete_threshold_count", fallback=5)

    @property
    def delete_threshold_seconds(self) -> int:
        return self.parser.getint("protection", "delete_threshold_seconds", fallback=60)

    @property
    def enable_review_reminder(self) -> bool:
        return self.parser.getboolean("review", "enable_review_reminder", fallback=True)

    @property
    def default_review_days(self) -> int:
        return self.parser.getint("review", "default_review_days", fallback=14)


class DeleteGuardHandler(FileSystemEventHandler):
    """監控 .md 刪除事件並在閾值超過時觸發緊急備份。"""

    def __init__(self, app: "KBGuardianApp") -> None:
        super().__init__()
        self.app = app
        self.deleted_events: deque[float] = deque()

    def on_deleted(self, event):  # type: ignore[override]
        """收到刪除事件時累積統計。"""
        try:
            if event.is_directory:
                return
            if not str(event.src_path).lower().endswith(".md"):
                return
            now = time.time()
            self.deleted_events.append(now)
            window = self.app.cfg.delete_threshold_seconds
            while self.deleted_events and now - self.deleted_events[0] > window:
                self.deleted_events.popleft()

            if len(self.deleted_events) > self.app.cfg.delete_threshold_count:
                self.deleted_events.clear()
                self.app.on_mass_delete_detected()
        except Exception:
            self.app.logger.exception("DeleteGuard 處理事件失敗")


class KBGuardianApp:
    """KB-Guardian GUI 與核心流程。"""

    def __init__(self) -> None:
        self.root_dir = get_runtime_root()
        self.cfg = AppConfig(self.root_dir)
        self.logger = self._setup_logger()
        self.observer: Observer | None = None

        self.cfg.backups_dir.mkdir(parents=True, exist_ok=True)
        self.cfg.exports_dir.mkdir(parents=True, exist_ok=True)

        self.ui = tk.Tk()
        self.ui.title(f"{APP_NAME} {APP_VERSION}")
        self.ui.geometry("860x620")
        self.ui.configure(bg="#F5F5F5")
        self.font_name = "Microsoft JhengHei"

        self.last_backup_var = tk.StringVar(value="尚未備份")
        self.page_count_var = tk.StringVar(value="0")
        self.recent_var = tk.StringVar(value="")
        self.guard_var = tk.StringVar(value="Delete Guard：未啟用")
        self.review_var = tk.StringVar(value="複習提醒：無")

        self._set_window_icon()
        self._build_ui()
        self._refresh_status()

        if self.cfg.enable_delete_guard:
            self._start_delete_guard()

        if self.cfg.auto_backup_on_launch:
            self._run_bg(self.backup_kb, notify=False)

    def _set_window_icon(self) -> None:
        """設定視窗圖示（.ico 檔，優先找 exe 旁，再找 _MEIPASS）。"""
        try:
            icon_path = self.root_dir / "icon.ico"
            if not icon_path.exists():
                meipass = getattr(sys, "_MEIPASS", None)
                if meipass:
                    icon_path = Path(meipass) / "icon.ico"
            if icon_path.exists():
                self.ui.iconbitmap(str(icon_path))
        except Exception:
            pass  # 無圖示時靜默略過，不影響主流程

    def _setup_logger(self) -> logging.Logger:
        """建立檔案日誌器。"""
        log_dir = self.root_dir / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        logger = logging.getLogger("kb_guardian")
        logger.setLevel(logging.INFO)
        if not logger.handlers:
            fh = logging.FileHandler(log_dir / "app.log", encoding="utf-8")
            fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
            fh.setFormatter(fmt)
            logger.addHandler(fh)
        return logger

    def _build_ui(self) -> None:
        """建立視窗與按鈕。"""
        title = tk.Label(self.ui, text=f"{APP_NAME} {APP_VERSION}", font=(self.font_name, 16, "bold"), bg="#F5F5F5")
        title.pack(pady=14)

        btn_frame = tk.Frame(self.ui, bg="#F5F5F5")
        btn_frame.pack(pady=8)

        buttons = [
            ("開啟知識庫", self.launch_logseq),
            ("開始錄影", self.launch_obs),
            ("立即備份", lambda: self._run_bg(self.backup_kb, notify=True)),
            ("匯出 SOP", self.export_sop),
            ("還原備份", self.restore_backup),
            ("重新整理", self._refresh_status),
        ]

        for i, (text, cmd) in enumerate(buttons):
            b = tk.Button(
                btn_frame,
                text=text,
                width=18,
                bg="#4A90D9",
                fg="white",
                font=(self.font_name, 11),
                command=cmd,
            )
            b.grid(row=i // 2, column=i % 2, padx=10, pady=10)

        status_box = tk.LabelFrame(self.ui, text="狀態資訊", padx=10, pady=10, bg="#F5F5F5", font=(self.font_name, 11, "bold"))
        status_box.pack(fill="x", padx=20, pady=12)

        tk.Label(status_box, text="上次備份：", bg="#F5F5F5", font=(self.font_name, 11)).grid(row=0, column=0, sticky="w")
        tk.Label(status_box, textvariable=self.last_backup_var, bg="#F5F5F5", font=(self.font_name, 11)).grid(row=0, column=1, sticky="w")

        tk.Label(status_box, text="知識庫頁面數：", bg="#F5F5F5", font=(self.font_name, 11)).grid(row=1, column=0, sticky="w")
        tk.Label(status_box, textvariable=self.page_count_var, bg="#F5F5F5", font=(self.font_name, 11)).grid(row=1, column=1, sticky="w")

        tk.Label(status_box, textvariable=self.guard_var, bg="#F5F5F5", fg="#A94442", font=(self.font_name, 10)).grid(row=2, column=0, columnspan=2, sticky="w", pady=(6, 0))
        tk.Label(status_box, textvariable=self.review_var, bg="#F5F5F5", fg="#8A6D3B", justify="left", anchor="w", font=(self.font_name, 10)).grid(row=3, column=0, columnspan=2, sticky="w", pady=(6, 0))

        recent_box = tk.LabelFrame(self.ui, text="最近修改（前5筆）", padx=10, pady=10, bg="#F5F5F5", font=(self.font_name, 11, "bold"))
        recent_box.pack(fill="both", expand=True, padx=20, pady=12)
        tk.Label(recent_box, textvariable=self.recent_var, justify="left", anchor="w", bg="#F5F5F5", font=(self.font_name, 10)).pack(fill="both", expand=True)

    def _run_bg(self, func, notify: bool = False) -> None:
        """在背景執行長任務，避免卡住主 UI。"""
        def _runner() -> None:
            try:
                func()
                self._refresh_status()
                if notify:
                    self.ui.after(0, lambda: messagebox.showinfo("完成", "作業完成。"))
            except Exception as exc:
                self.logger.exception("背景任務失敗")
                self.ui.after(0, lambda: messagebox.showerror("錯誤", f"作業失敗：{exc}"))

        threading.Thread(target=_runner, daemon=True).start()

    def _refresh_status(self) -> None:
        """更新狀態資訊。"""
        try:
            latest = self._latest_backup_file()
            self.last_backup_var.set(latest.stem if latest else "尚未備份")
            self.page_count_var.set(str(self._count_pages()))
            self.recent_var.set("\n".join(self._recent_files()) or "（無資料）")
            self.review_var.set(self._review_summary())
        except Exception:
            self.logger.exception("更新狀態失敗")

    def _latest_backup_file(self) -> Path | None:
        backups = sorted(self.cfg.backups_dir.glob("KB_backup_*.zip"), key=lambda p: p.stat().st_mtime, reverse=True)
        return backups[0] if backups else None

    def _count_pages(self) -> int:
        pages = self.cfg.kb_root / "pages"
        if not pages.exists():
            return 0
        return len(list(pages.glob("*.md")))

    def _recent_files(self) -> list[str]:
        candidates = []
        for sub in [self.cfg.kb_root / "pages", self.cfg.kb_root / "journals"]:
            if sub.exists():
                candidates.extend([p for p in sub.glob("*.md") if p.is_file()])
        candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
        out = []
        for p in candidates[:5]:
            ts = datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
            out.append(f"{ts}  {p.name}")
        return out

    def _start_delete_guard(self) -> None:
        """啟動刪除保護監控器。"""
        if not WATCHDOG_AVAILABLE:
            self.guard_var.set("Delete Guard：watchdog 未安裝（已略過）")
            self.logger.warning("watchdog 未安裝，無法啟用 Delete Guard")
            return
        if not self.cfg.kb_root.exists():
            self.guard_var.set("Delete Guard：KB 路徑不存在")
            return
        handler = DeleteGuardHandler(self)
        self.observer = Observer()
        self.observer.schedule(handler, str(self.cfg.kb_root), recursive=True)
        self.observer.start()
        self.guard_var.set("Delete Guard：已啟用")

    def _review_summary(self) -> str:
        """計算並產生複習提醒摘要。"""
        if not self.cfg.enable_review_reminder:
            return "複習提醒：已停用"

        overdue = self._collect_review_overdue(limit=3)
        if not overdue:
            return "複習提醒：目前無逾期 SOP"

        lines = [f"複習提醒：{len(overdue)} 筆逾期（顯示前3筆）"]
        for name, days in overdue[:3]:
            lines.append(f"• {name}（逾期 {days} 天）")
        return "\n".join(lines)

    def _collect_review_overdue(self, limit: int = 20) -> list[tuple[str, int]]:
        """掃描 SOP 檔案並找出逾期複習項目。"""
        pages_dir = self.cfg.kb_root / "pages"
        if not pages_dir.exists():
            return []

        items: list[tuple[str, int]] = []
        now = datetime.now().date()
        for md_file in pages_dir.glob("*.md"):
            try:
                text = md_file.read_text(encoding="utf-8", errors="ignore")
                last_review = self._extract_review_date(text)
                review_days = self._extract_review_cycle_days(text)
                if not last_review:
                    continue
                overdue_days = (now - last_review).days - review_days
                if overdue_days > 0:
                    items.append((md_file.stem, overdue_days))
            except Exception:
                self.logger.exception("解析複習資訊失敗：%s", md_file)

        items.sort(key=lambda x: x[1], reverse=True)
        return items[:limit]

    def _extract_review_date(self, text: str):
        """從頁面文字抽取「最後複習」日期。"""
        m = re.search(r"最後複習::\s*(?:\[\[)?(\d{4}-\d{2}-\d{2})(?:\]\])?", text)
        if not m:
            return None
        try:
            return datetime.strptime(m.group(1), "%Y-%m-%d").date()
        except ValueError:
            return None

    def _extract_review_cycle_days(self, text: str) -> int:
        """從頁面文字抽取「複習週期」，若缺少則回預設天數。"""
        m = re.search(r"複習週期::\s*(\d+)\s*天?", text)
        if not m:
            return self.cfg.default_review_days
        try:
            return max(1, int(m.group(1)))
        except ValueError:
            return self.cfg.default_review_days

    def on_mass_delete_detected(self) -> None:
        """偵測大量刪除時執行緊急備份與警示。"""
        self.logger.warning("偵測到短時間大量刪除，觸發緊急備份")
        self.backup_kb(prefix="KB_emergency")
        self.ui.after(0, lambda: messagebox.showwarning("警告", "偵測到短時間大量刪除，已建立緊急備份。"))

    def backup_kb(self, prefix: str = "KB_backup") -> None:
        """建立 KB 壓縮備份，並清理超量舊檔。"""
        create_backup_archive(self.cfg.kb_root, self.cfg.backups_dir, self.cfg.max_backups, self.logger, prefix=prefix)

    def launch_logseq(self) -> None:
        """啟動 Logseq，可選擇先自動備份。備份在背景執行，不凍結 UI。"""
        def _do() -> None:
            if self.cfg.auto_backup_on_launch:
                self.backup_kb()
            self._launch_exe(self.cfg.logseq_exe)
        self._run_bg(_do)

    def launch_obs(self) -> None:
        """啟動 OBS。"""
        try:
            self._launch_exe(self.cfg.obs_exe)
        except Exception as exc:
            self.logger.exception("啟動 OBS 失敗")
            messagebox.showerror("錯誤", str(exc))

    def _launch_exe(self, exe: Path) -> None:
        """啟動外部程式。"""
        if not exe.exists():
            raise FileNotFoundError(f"找不到執行檔：{exe}")
        subprocess.Popen([str(exe)], cwd=str(exe.parent))

    def export_sop(self) -> None:
        """匯出單一 SOP 為 TXT 與 PDF。
        filedialog 在主執行緒呼叫；pandoc 執行移至背景執行緒，避免 UI 凍結。
        """
        pages_dir = self.cfg.kb_root / "pages"
        if not pages_dir.exists():
            messagebox.showerror("錯誤", f"找不到 pages 目錄：{pages_dir}")
            return
        pandoc = self.cfg.pandoc_exe
        if not pandoc.exists():
            messagebox.showerror("錯誤", f"找不到 Pandoc：{pandoc}")
            return

        # filedialog 必須在主執行緒呼叫
        src = filedialog.askopenfilename(
            title="選擇要匯出的 SOP",
            initialdir=str(pages_dir),
            filetypes=[("Markdown", "*.md")],
        )
        if not src:
            return
        src_path = Path(src)

        def _do() -> None:
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
            base_name = f"SOP_{src_path.stem}_{ts}"
            txt_out = self.cfg.exports_dir / f"{base_name}.txt"
            pdf_out = self.cfg.exports_dir / f"{base_name}.pdf"
            subprocess.run([str(pandoc), str(src_path), "-o", str(txt_out)], check=True)
            subprocess.run([str(pandoc), str(src_path), "-o", str(pdf_out)], check=True)
            self.logger.info("匯出完成：%s, %s", txt_out, pdf_out)

        self._run_bg(_do, notify=True)

    def restore_backup(self) -> None:
        """選擇備份檔並還原 KB。
        filedialog 與確認對話框在主執行緒；備份＋解壓在背景執行緒，避免 UI 凍結。
        """
        zip_file = filedialog.askopenfilename(
            title="選擇備份檔",
            initialdir=str(self.cfg.backups_dir),
            filetypes=[("ZIP", "*.zip")],
        )
        if not zip_file:
            return
        if not messagebox.askyesno("確認", "還原會覆蓋現有 KB，是否繼續？"):
            return

        def _do() -> None:
            # 還原前先做一次保險備份
            self.backup_kb(prefix="KB_pre_restore")

            tmp_dir = self.root_dir / "_restore_tmp"
            if tmp_dir.exists():
                shutil.rmtree(tmp_dir, ignore_errors=True)
            tmp_dir.mkdir(parents=True, exist_ok=True)

            try:
                with zipfile.ZipFile(zip_file, "r") as zf:
                    zf.extractall(tmp_dir)

                restored_kb = tmp_dir / self.cfg.kb_root.name
                if not restored_kb.exists():
                    # 相容：若 zip 直接從 KB 目錄內部開始壓
                    restored_kb = tmp_dir

                if self.cfg.kb_root.exists():
                    shutil.rmtree(self.cfg.kb_root, ignore_errors=True)
                shutil.copytree(restored_kb, self.cfg.kb_root)
                self.logger.info("還原完成：%s", zip_file)
            finally:
                shutil.rmtree(tmp_dir, ignore_errors=True)

        self._run_bg(_do, notify=True)

    def run(self) -> None:
        """啟動 UI 主迴圈。"""
        try:
            self.ui.mainloop()
        finally:
            if self.observer:
                self.observer.stop()
                self.observer.join(timeout=2)


def main() -> None:
    """程式進入點。"""
    app = KBGuardianApp()
    app.run()


if __name__ == "__main__":
    main()
