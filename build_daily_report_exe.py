"""Build a single-file DailySalesReport.exe using PyInstaller.

    python build_daily_report_exe.py

The resulting exe is written to:   dist\\DailySalesReport.exe
It reads `config.env` (or `.env`) from the folder the exe is run from.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def ensure_pyinstaller() -> None:
    try:
        import PyInstaller  # noqa: F401
    except ImportError:
        print("[build] installing pyinstaller...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])


def main() -> int:
    ensure_pyinstaller()

    # Clean previous output for a reproducible build.
    for d in ("build", "dist"):
        p = ROOT / d
        if p.exists():
            shutil.rmtree(p, ignore_errors=True)
    spec = ROOT / "DailySalesReport.spec"
    if spec.exists():
        spec.unlink()

    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--onefile",
        "--console",
        "--name", "DailySalesReport",
        "--noconfirm",
        "--clean",
        # Make sure helper modules are bundled (they're imported dynamically
        # via the CLI module so PyInstaller picks them up automatically, but
        # list them explicitly for safety).
        "--hidden-import", "report_db",
        "--hidden-import", "report_render",
        "--hidden-import", "report_mailer",
        "--hidden-import", "openpyxl",
        "--hidden-import", "xlsxwriter",
        "--hidden-import", "pyodbc",
        "--hidden-import", "dotenv",
        "--hidden-import", "jinja2",
        "--hidden-import", "markupsafe",
        # Exclude large libraries we don't use
        "--exclude-module", "streamlit",
        "--exclude-module", "matplotlib",
        "--exclude-module", "scipy",
        "--exclude-module", "PIL",
        "--exclude-module", "notebook",
        "--exclude-module", "IPython",
        "--exclude-module", "tkinter",
        "daily_report.py",
    ]

    print("[build] running:", " ".join(cmd))
    rc = subprocess.call(cmd, cwd=str(ROOT))
    if rc != 0:
        print(f"[build] FAILED with exit code {rc}")
        return rc

    exe = ROOT / "dist" / "DailySalesReport.exe"
    if not exe.exists():
        print(f"[build] ERROR: expected {exe} was not produced")
        return 2

    print()
    print("[build] SUCCESS")
    print(f"[build] exe:  {exe}  ({exe.stat().st_size/1024/1024:.1f} MB)")
    print()
    print("Next: copy the exe plus config.env.example into a deploy folder")
    print("      (or just run `python build_deploy_package.py` after this).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
