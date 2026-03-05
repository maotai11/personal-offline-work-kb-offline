# KB-Guardian Releases

## v0.1.0 (2026-03-05)

### Build Info
- **Platform:** Linux x86_64
- **Python:** 3.11.14
- **PyInstaller:** 6.19.0
- **Build Command:** `pyinstaller --onedir --windowed --name kb-guardian --add-data "config.ini:." kb_guardian/main.py`

### Files
| File | Size | SHA256 |
|------|------|--------|
| `kb-guardian-linux-v0.1.0-20260305.zip` | 8.2 MB | `9b920d345f41a086d45b24ea28bb7b23eb56e53a700536f489e3ef92b7f70bb3` |

### Contents
```
dist/kb-guardian/
├── kb-guardian          # Executable
└── _internal/
    ├── config.ini       # Default configuration
    ├── base_library.zip
    ├── libpython3.11.so.1.0
    └── ... (other runtime libraries)
```

### Notes
- This is a Linux build. For Windows, run PyInstaller on a Windows machine.
- tkinter must be installed on the target system (`python3-tk` package).
