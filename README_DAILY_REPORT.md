# Daily Sales Report — pcAmerica CRE (`cresqlvick`)

This tool generates a detailed **per-merchant daily sales report** directly from
the pcAmerica `cresqlvick` SQL Server database and emails each report to the
merchant email that's stored in `dbo.Setup`.

It reuses the exact `Dept_ID` whitelist from `FixedTaxApp.py`, so the numbers
stay aligned with the cigar/tobacco departments this business actually sells.

## What it reports

For every `Store_ID` in `dbo.Setup`, per day (or date range):

- Header: store description, address, phone, Tax ID, Store_ID, report date.
- KPIs: invoice count, net sales, taxed/non-taxed/tax-exempt sales, sales
  tax (`Tax1Per+Tax2Per+Tax3Per`), fixed tax collected
  (`Inventory.Fixed_Tax * Quantity`), discounts, cash collected, average ticket.
- Breakdown tables:
  - Sales by Department (with % of day's revenue)
  - Sales by Fixed-Tax bucket
  - Top 20 items
  - Sales by hour of day
  - Payment-type breakdown
- Full itemized transaction detail (as an Excel sheet and as a CSV).

Each run also saves an HTML copy and XLSX copy under:

```
.\daily_reports\{YYYY-MM-DD}\{Store_ID}\
```

## Files in this folder

| File | Purpose |
| ---- | ------- |
| `daily_report.py` | CLI entry point |
| `report_db.py` | pyodbc connection + all parameterized SQL |
| `report_render.py` | HTML + XLSX rendering |
| `report_mailer.py` | SMTP sending with attachments |
| `requirements.txt` | Python dependencies |
| `.env.example` | Sample configuration (copy to `.env` and fill in) |
| `.gitignore` | Keeps `.env` and `daily_reports/` out of git |

## 1. One-time setup

From an elevated PowerShell in this folder:

```powershell
python -m pip install -r requirements.txt
```

You need an ODBC driver for SQL Server — one of `ODBC Driver 17 for SQL Server`,
`ODBC Driver 18 for SQL Server`, or the legacy `SQL Server` driver. All of the
drivers ship with most Windows + SQL Server installs; the script auto-selects
the newest one.

## 2. Configure `.env`

Copy the template and fill it in:

```powershell
copy ".env.example" ".env"
notepad ".env"
```

Required keys:

```
SQL_SERVER=harshil\pcamerica
SQL_DATABASE=cresqlvick
SQL_AUTH=windows                  # or "sql"
SQL_USER=
SQL_PASSWORD=

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=you@gmail.com
SMTP_PASSWORD=your_gmail_app_password
SMTP_FROM="Daily Reports <you@gmail.com>"
SMTP_USE_TLS=true

DRY_RUN=false
```

Optional:

```
REPORT_DATE_MODE=latest
```

`REPORT_DATE_MODE` controls what happens when you do not pass `--date` or
`--start/--end`:
- `latest` (recommended): use the most recent invoice date found in SQL
- `yesterday`: always use yesterday
- `today`: always use today

**Gmail note:** `SMTP_PASSWORD` must be a **Google App Password**, not your
regular login password. Create one at
<https://myaccount.google.com/apppasswords> (requires 2-step verification).

## 3. Run it

```powershell
# Default: yesterday, all stores, send email
python daily_report.py

# Specific day
python daily_report.py --date 2026-04-21

# Custom range
python daily_report.py --start 2026-04-01 --end 2026-04-21

# Single store
python daily_report.py --store 1001

# Generate files, DO NOT email (recommended for first run)
python daily_report.py --dry-run --date 2026-04-21

# Override recipient (for testing against your own inbox)
python daily_report.py --dry-run --to you@example.com

# CC / BCC
python daily_report.py --cc boss@example.com --bcc archive@example.com
```

Outputs are written to:

```
.\daily_reports\{YYYY-MM-DD}\{Store_ID}\daily_sales_{Store_ID}_{YYYY-MM-DD}.html
.\daily_reports\{YYYY-MM-DD}\{Store_ID}\daily_sales_{Store_ID}_{YYYY-MM-DD}.xlsx
.\daily_reports\{YYYY-MM-DD}\{Store_ID}\daily_sales_{Store_ID}_{YYYY-MM-DD}_transactions.csv
```

At the end of a run you'll see a summary:

```
=== Summary ===
Stores processed: N
Emails sent:      N   (or "0 — DRY RUN")
Stores skipped:   list of Store_IDs and reason
```

## 4. Schedule it (Windows Task Scheduler)

To run the script daily at 7:00 AM completely in the background (hidden) under your current Windows user, paste this into an **elevated PowerShell** window (make sure the path points to your `daily_report.py` file):

```powershell
schtasks /Create /SC DAILY /ST 07:00 /TN "CRE Daily Sales Report" /RL HIGHEST /F ^
  /TR "powershell -WindowStyle Hidden -Command \"python 'c:\Users\harsh\OneDrive\Desktop\ashwinbhai email\daily_report.py'\""
```

To inspect / remove later:

```powershell
schtasks /Query /TN "CRE Daily Sales Report"
schtasks /Delete /TN "CRE Daily Sales Report" /F
```

> The task will run as the currently logged-in user, so the Windows
> Authentication connection to `harshil\pcamerica` continues to work. Make
> sure `python` is on `PATH` for that user.

Every run also writes local copies of reports to disk, and appends console output to `daily_report_run.log` in the project directory.

## 5. Troubleshooting

- **Check the log file** — look at `daily_report_run.log` in the script directory to view the execution history and any error messages.
- **`.env` missing** — the script prints setup instructions and exits.
- **No SMTP configured but `--dry-run` not set** — the script auto-falls back
  to dry-run (it generates files but does not try to send).
- **No email sent** — set `REPORT_RECIPIENT` in `.env` / `config.env` with the
  address(es) that should receive every store’s report. `dbo.Setup` store
  emails are not used for delivery.
- **ODBC driver error** — install "Microsoft ODBC Driver 17 for SQL Server"
  from Microsoft's download site.
