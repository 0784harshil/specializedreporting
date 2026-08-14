"""Assemble a shippable deploy\\ folder for merchants.

Run after `build_daily_report_exe.py`.

Deploy model: a SINGLE .exe. On first run the exe writes `config.env`
next to itself (from a template embedded inside the exe) and opens it in
Notepad. After the merchant edits + saves, re-running the exe does the
actual work.

Produces:
    deploy\\DailySalesReport.exe
    deploy\\README_DEPLOY.md
    DailySalesReport_deploy.zip    (zip of the above)
"""

from __future__ import annotations

import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EXE = ROOT / "dist" / "DailySalesReport.exe"
OUT = ROOT / "deploy"


README = r"""# Daily Sales Report - Merchant Install Guide

One file to ship: `DailySalesReport.exe`. No Python, no installer, no zip to
unpack anything from.

## Install (merchant, on their POS PC)

1. Put `DailySalesReport.exe` somewhere permanent, e.g. `C:\DailySalesReport\`.
   Don't use OneDrive, Program Files, or any path that requires admin writes
   or is cloud-synced. The app writes reports into a `daily_reports\` folder
   next to the exe.
2. Double-click `DailySalesReport.exe`.
   - First run: it creates `config.env` next to itself and opens it in
     Notepad.
3. Fill in `config.env`:
   - `SQL_SERVER` - this PC's SQL Server instance
     (common: `.\pcamerica`, `LOCALHOST\pcamerica`, or `<MACHINE>\pcamerica`).
   - `SMTP_USER` / `SMTP_PASSWORD` - Gmail address + **App Password**
     (create one at <https://myaccount.google.com/apppasswords>).
   - `SMTP_FROM` - friendly name + address (e.g.
     `Daily Reports <you@gmail.com>`).
   - `REPORT_RECIPIENT` - the merchant's email address.
4. Save + close Notepad, then double-click `DailySalesReport.exe` again.
   It will pull yesterday's sales, email the report, and save the HTML/XLSX
   into `daily_reports\YYYY-MM-DD\<Store_ID>\`.

## Schedule it to run every morning

To run the script every morning at 7:00 AM completely in the background (hidden), paste this into an elevated PowerShell (edit the path to where you put the exe):

```powershell
schtasks /Create /SC DAILY /ST 07:00 /TN "CRE Daily Sales Report" /RL HIGHEST /F ^
    /TR "powershell -WindowStyle Hidden -Command \"& 'C:\DailySalesReport\DailySalesReport.exe'\""
```

To remove later:

```powershell
schtasks /Delete /TN "CRE Daily Sales Report" /F
```

## Command-line flags (optional)

```
DailySalesReport.exe                          :: yesterday, all stores, send
DailySalesReport.exe --date 2026-04-21        :: specific day
DailySalesReport.exe --start 2026-04-01 --end 2026-04-21
DailySalesReport.exe --store 1001             :: single Store_ID
DailySalesReport.exe --dry-run                :: generate files, no email
DailySalesReport.exe --to someone@x.com       :: override recipient (testing)
```

## Who receives the email

Reports are sent **only** to addresses in `config.env`:

1. `--to` on the command line (optional; overrides `REPORT_RECIPIENT` for that run)
2. Otherwise `REPORT_RECIPIENT` in `config.env` (comma-separated list)

`dbo.Setup` store email columns are **not** used for delivery.

## Reports and logs saved to disk

Every run also writes local copies (so they survive even if email fails):

```
<folder of exe>\daily_reports\YYYY-MM-DD\<Store_ID>\
    daily_sales_<Store_ID>_<YYYY-MM-DD>.html
    daily_sales_<Store_ID>_<YYYY-MM-DD>.xlsx
    daily_sales_<Store_ID>_<YYYY-MM-DD>_transactions.csv
```

A log file named `daily_report_run.log` is also created/updated in the folder containing the exe. It contains the console outputs of every run.

## Troubleshooting

- **Check the log file** - check `daily_report_run.log` next to the exe for error details of the runs.
- **"No ODBC 'SQL Server' driver found"** - install
  [Microsoft ODBC Driver 17 for SQL Server](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server).
- **Gmail rejects login** - you used your regular Gmail password. You need
  a Google **App Password** instead (2-Step Verification must be on).
- **"REPORT_RECIPIENT is not set"** - add at least one address to
  `REPORT_RECIPIENT=` in `config.env` (required to send email).
- **First run closes instantly** - run it from a Command Prompt to see the
  output: open `cmd.exe` in the exe's folder and type `DailySalesReport.exe`.
- **Windows SmartScreen warning** - the exe is unsigned. Click "More info"
  -> "Run anyway". It's safe; you can code-sign it later if you want the
  warning gone.

## Re-configure later

Edit `config.env` in Notepad. No reinstall needed.

## Uninstall

Delete the folder and (if scheduled) run
`schtasks /Delete /TN "CRE Daily Sales Report" /F`.
"""


def main() -> int:
    if not EXE.exists():
        print(f"[deploy] Missing {EXE}. Run `python build_daily_report_exe.py` first.")
        return 1

    if OUT.exists():
        shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True, exist_ok=True)

    shutil.copy2(EXE, OUT / EXE.name)
    (OUT / "README_DEPLOY.md").write_text(README, encoding="utf-8")

    # Single-file zip for easy handoff (optional — you can also just send the
    # exe directly; the README is only there for convenience).
    zip_path = OUT.parent / "DailySalesReport_deploy.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for item in OUT.iterdir():
            z.write(item, arcname=item.name)

    print("[deploy] wrote:")
    for item in OUT.iterdir():
        size_mb = item.stat().st_size / 1024 / 1024
        print(f"  {item}   ({size_mb:.1f} MB)")
    print()
    print(f"[deploy] zip : {zip_path}   ({zip_path.stat().st_size/1024/1024:.1f} MB)")
    print()
    print("Hand DailySalesReport.exe to each merchant. They double-click it;")
    print("it self-creates config.env on first run and opens it in Notepad.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
