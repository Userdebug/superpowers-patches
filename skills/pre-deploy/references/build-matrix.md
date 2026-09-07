# Build Matrix — OS × Packager

Primary packager: **PyInstaller** (recommended for PyQt6). Others are fallbacks.

## Why cross-build fails

| Host → Target | Works? | Notes |
|---------------|--------|-------|
| Linux → Windows `.exe` | **No** | Qt/PyQt wheels + MSVC redist are OS-specific. Wine is not a supported shortcut. |
| Linux → macOS `.app` | **No** | Requires `macos-latest` runner + signing/notarization. |
| Windows → Linux | **No** | GLIBC/Qt version mismatch. |
| Any → same OS | **Yes** | Build on the OS you ship. |

Rule: ship Windows on `windows-latest`, macOS on `macos-latest`, Linux on `ubuntu-latest`.

## PyInstaller pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Missing `hiddenimports` | `ModuleNotFoundError` at launch only | `hiddenimports=['PyQt6.sip', 'pkg_resources']` + custom hooks for `reportlab`/`openpyxl`/`Pillow` |
| Qt platform plugin absent | `could not find Qt platform plugin "windows"` | Include `PyQt6/Qt6/plugins/platforms` via hook or `binaries` |
| Absolute dev path | Works on dev, fails in bundle | `BASE_DIR = getattr(sys, '_MEIPASS', os.path.dirname(__file__))` pattern |
| `onefile` before `onedir` | Slow debug, hidden missing datas | Always validate `onedir` first |
| Antivirus false positive | `.exe` flagged on Windows | Sign + submit to Defender SmartScreen; `onefile` is more often flagged than `onedir` |

## Minimal GitHub Actions (matrix)

```yaml
name: build
on: { push: { tags: ["v*"] }, workflow_dispatch: {} }
jobs:
  build:
    strategy: { matrix: { os: [windows-latest, ubuntu-latest] } } # add macos-latest when needed
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12", cache: "pip" }
      - run: pip install -r requirements.txt
      - run: python -m py_compile main.py
      - run: python -m pytest -q
      - run: pyinstaller --onedir --name app main.py  # add --windowed on Windows
      - run: sha256sum dist/app/*  # shasum -a 256 on macOS/Windows
      - uses: actions/upload-artifact@v4
        with: { name: app-${{ matrix.os }}, path: dist/ }
```

Adapt `pyinstaller` args to your `datas`/`hooks`/`binaries`. Nuitka/cx_Freeze replace the `pyinstaller` step; the matrix and `sha256` steps stay.
