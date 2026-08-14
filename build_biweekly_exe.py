"""Build BiWeeklyEmployeeReport.exe and stage it into Bi weekly Swapnil.

    python build_biweekly_exe.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
OUT_FOLDER = ROOT / "Bi weekly Swapnil"


def ensure_pyinstaller() -> None:
    try:
        import PyInstaller  # noqa: F401
    except ImportError:
        print("[build] installing pyinstaller...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])


def main() -> int:
    ensure_pyinstaller()

    for d in ("build", "dist"):
        # Do not wipe DailySalesReport artifacts if present — only clean
        # our own named outputs after build. PyInstaller --clean handles
        # per-spec build cache for this target.
        pass

    spec = ROOT / "BiWeeklyEmployeeReport.spec"
    if spec.exists():
        spec.unlink()

    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--onefile",
        "--console",
        "--name", "BiWeeklyEmployeeReport",
        "--noconfirm",
        "--clean",
        "--hidden-import", "report_db",
        "--hidden-import", "report_mailer",
        "--hidden-import", "openpyxl",
        "--hidden-import", "xlsxwriter",
        "--hidden-import", "pyodbc",
        "--hidden-import", "dotenv",
        "--exclude-module", "streamlit",
        "--exclude-module", "matplotlib",
        "--exclude-module", "scipy",
        "--exclude-module", "PIL",
        "--exclude-module", "notebook",
        "--exclude-module", "IPython",
        "--exclude-module", "tkinter",
        "--exclude-module", "jinja2",
        "employee_biweekly_report.py",
    ]

    print("[build] running:", " ".join(cmd))
    rc = subprocess.call(cmd, cwd=str(ROOT))
    if rc != 0:
        print(f"[build] FAILED with exit code {rc}")
        return rc

    exe = ROOT / "dist" / "BiWeeklyEmployeeReport.exe"
    if not exe.exists():
        print(f"[build] ERROR: expected {exe} was not produced")
        return 2

    OUT_FOLDER.mkdir(parents=True, exist_ok=True)
    shutil.copy2(exe, OUT_FOLDER / "BiWeeklyEmployeeReport.exe")

    cfg = OUT_FOLDER / "config.env"
    if not cfg.exists():
        cfg.write_text(
            """\
# ------------------------------------------------------------------
# Bi-Weekly Employee Hours Report - Swapnil
# ------------------------------------------------------------------
#
# Half-month periods auto-detect last day (28/29/30/31):
#   Half 1 = 1st–15th
#   Half 2 = 16th–last day of month
#
# REPORT_PERIOD_MODE:
#   latest   = half-month containing the newest Time_Clock punch (default)
#   previous = most recently completed half-month
#   current  = half containing today

SQL_SERVER=Harshil\\pcamerica
SQL_DATABASE=cresqljd
SQL_AUTH=sql
SQL_USER=sa
SQL_PASSWORD=pcAmer1ca

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=harshil@jdgurus.com
SMTP_PASSWORD=hllu otlp dhkl fkxh
SMTP_FROM=Bi-Weekly Hours <harshil@jdgurus.com>
SMTP_USE_TLS=true

REPORT_RECIPIENT=harshil@jdgurus.com
REPORT_PERIOD_MODE=latest
DRY_RUN=false
""",
            encoding="utf-8",
        )

    readme = OUT_FOLDER / "README.md"
    readme.write_text(
        """# Bi-Weekly Employee Hours Report (Swapnil)

Employee **hours only** (Time_Clock). No sales sections.

## Half-month periods (auto)

| Half | Days |
|------|------|
| 1 | 1st – 15th |
| 2 | 16th – last day of month (28 / 29 / 30 / 31 detected automatically) |

Default run uses the **most recently completed** half (`REPORT_PERIOD_MODE=previous`).

## Run

```
BiWeeklyEmployeeReport.exe
BiWeeklyEmployeeReport.exe --dry-run
BiWeeklyEmployeeReport.exe --half 1 --month 2026-07
BiWeeklyEmployeeReport.exe --half 2 --month 2026-07
BiWeeklyEmployeeReport.exe --start 2026-07-01 --end 2026-07-15
BiWeeklyEmployeeReport.exe --store 1001
```

Edit `config.env` next to the exe for SQL / email settings.

Reports are saved under `biweekly_reports\\YYYY-MM-DD_to_YYYY-MM-DD\\<Store_ID>\\`.
""",
        encoding="utf-8",
    )

    print()
    print("[build] SUCCESS")
    print(f"[build] exe:     {exe}  ({exe.stat().st_size / 1024 / 1024:.1f} MB)")
    print(f"[build] staged:  {OUT_FOLDER}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
