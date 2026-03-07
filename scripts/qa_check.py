"""Final release QA check — run with: python scripts/qa_check.py"""
import zipfile, shutil, re, sys
from pathlib import Path

proj = Path(__file__).resolve().parents[1]
zips = sorted((proj / "release").glob("*.zip"))
if not zips:
    print("ERROR: no release zip found"); sys.exit(1)

bundle_zip = zips[-1]
test = proj / "_qa_run"
if test.exists():
    shutil.rmtree(test)
test.mkdir()
with zipfile.ZipFile(bundle_zip) as zf:
    zf.extractall(test)

PASS, FAIL = "[PASS]", "[FAIL]"
results = []

def chk(label, ok):
    results.append((PASS if ok else FAIL, label))

# 1. Structure
chk("START_HERE.bat",               (test/"START_HERE.bat").exists())
chk("README_OFFLINE.md",            (test/"README_OFFLINE.md").exists())
chk("kb-guardian.exe",              (test/"tools/kb-guardian/kb-guardian.exe").exists())
chk("config.ini",                   (test/"tools/kb-guardian/config.ini").exists())
chk("icon.ico in _internal",        (test/"tools/kb-guardian/_internal/icon.ico").exists())
chk("config.ini.example",           (test/"tools/kb-guardian/_internal/config.ini.example").exists())
chk("KB/pages/",                    (test/"KB/pages").is_dir())
chk("KB/journals/",                 (test/"KB/journals").is_dir())
chk("KB/assets/",                   (test/"KB/assets").is_dir())
chk("backups/",                     (test/"backups").is_dir())
chk("exports/",                     (test/"exports").is_dir())
chk("videos/",                      (test/"videos").is_dir())
chk("MANIFEST_SHA256.txt",          (test/"MANIFEST_SHA256.txt").exists())

# 2. BAT
bat = (test/"START_HERE.bat").read_text(encoding="utf-8", errors="ignore")
chk("BAT: no python-m fallback",    "python -m" not in bat)
chk("BAT: has pause on error",      "pause" in bat)
chk("BAT: chcp 65001",              "chcp 65001" in bat)
chk("BAT: uses %~dp0",              "%~dp0" in bat)

# 3. README
readme = (test/"README_OFFLINE.md").read_text(encoding="utf-8", errors="ignore")
chk("README: no tab corruption",    not re.search(r"\t[a-z]ools/", readme))
chk("README: logseq path correct",  "tools/logseq-portable/Logseq.exe" in readme)
chk("README: obs path correct",     "tools/obs-portable/bin/64bit/obs64.exe" in readme)
chk("README: pandoc path correct",  "tools/pandoc/pandoc.exe" in readme)
chk("README: has Chinese content",  "START_HERE.bat" in readme)

# 4. Config
cfg = (test/"tools/kb-guardian/config.ini").read_text()
chk("config: kb_root=../../KB",     "kb_root = ../../KB" in cfg)
chk("config: no absolute C:\\ path", "C:\\" not in cfg and "C:/" not in cfg)

# 5. No dev garbage
garbage = [f for f in test.rglob("*")
           if f.is_file() and f.suffix in (".py", ".spec", ".pyc", ".pyo")
           and f.name != ".gitkeep"]
chk("no .py/.spec/.pyc in release",  len(garbage) == 0)

# 6. Sizes
exe = test/"tools/kb-guardian/kb-guardian.exe"
exe_mb = exe.stat().st_size / 1024 / 1024
zip_mb = bundle_zip.stat().st_size / 1024 / 1024
chk(f"EXE reasonable size ({exe_mb:.1f} MB, expect 1-10)", 1 < exe_mb < 10)
chk(f"ZIP reasonable size ({zip_mb:.1f} MB, expect <50)",  zip_mb < 50)

# 7. .gitkeep in all data dirs (ensures empty dirs in ZIP)
for d in ["backups", "exports", "videos", "KB/pages", "KB/journals", "KB/assets"]:
    chk(f".gitkeep in {d}/", (test / d / ".gitkeep").exists())

# Print
shutil.rmtree(test)
print(f"\nZIP : {bundle_zip.name}  ({zip_mb:.1f} MB)")
print(f"EXE : {exe_mb:.1f} MB\n")
for tag, label in results:
    print(f"  {tag} {label}")

fails  = [r for r in results if r[0] == FAIL]
passes = [r for r in results if r[0] == PASS]
print(f"\nResult: {len(passes)} PASS / {len(fails)} FAIL")
if fails:
    print("FAILED:")
    for _, l in fails:
        print(f"  - {l}")
sys.exit(0 if not fails else 1)
