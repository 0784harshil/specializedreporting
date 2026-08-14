"""Bi-weekly (semi-monthly / half-month) employee hours report.

Only reports Time_Clock employee hours/wages — no sales sections.

Half-month periods auto-detect month length (28/29/30/31):
    Half 1: day 1  -> 15
    Half 2: day 16 -> last day of month

Default when no dates are passed: the most recently *completed* half-month
(REPORT_PERIOD_MODE=previous). Use current / --half / --start/--end to override.

Usage:
    python employee_biweekly_report.py
    python employee_biweekly_report.py --dry-run
    python employee_biweekly_report.py --half 1 --month 2026-07
    python employee_biweekly_report.py --half 2 --month 2026-07
    python employee_biweekly_report.py --start 2026-07-01 --end 2026-07-15
    python employee_biweekly_report.py --store 1001
"""

from __future__ import annotations

import argparse
import calendar
import datetime as _dt
import os
import re
import sys
import warnings
from pathlib import Path
from typing import Optional

warnings.filterwarnings("ignore", message="pandas only supports SQLAlchemy")

from dotenv import load_dotenv
import pandas as pd

import report_db
import report_mailer


# ---------------------------------------------------------------------------
# Paths / config
# ---------------------------------------------------------------------------

def _app_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


SCRIPT_DIR = _app_dir()
OUTPUT_ROOT = SCRIPT_DIR / "biweekly_reports"
CONFIG_PATH = SCRIPT_DIR / "config.env"
_CONFIG_CANDIDATES = (CONFIG_PATH, SCRIPT_DIR / ".env")

CONFIG_TEMPLATE = """\
# ------------------------------------------------------------------
# Bi-Weekly Employee Hours Report - configuration
# Edit this file, save, then re-run BiWeeklyEmployeeReport.exe
# ------------------------------------------------------------------
#
# Keys read by the program:
#   SQL_SERVER, SQL_DATABASE, SQL_AUTH, SQL_USER, SQL_PASSWORD
#   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_FROM, SMTP_USE_TLS
#   REPORT_RECIPIENT, DRY_RUN, REPORT_PERIOD_MODE
#
# Half-month periods (auto last-day):
#   Half 1 = 1st–15th
#   Half 2 = 16th–last day of month (28/29/30/31)

# --- SQL Server (pcAmerica CRE) ---
SQL_SERVER=LOCALHOST\\pcamerica
SQL_DATABASE=cresqljd
SQL_AUTH=windows
SQL_USER=
SQL_PASSWORD=

# --- SMTP ---
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your.address@gmail.com
SMTP_PASSWORD=your_google_app_password
SMTP_FROM=Bi-Weekly Hours <your.address@gmail.com>
SMTP_USE_TLS=true

# --- Recipient (required to email) ---
REPORT_RECIPIENT=owner@example.com

# --- Other ---
# REPORT_PERIOD_MODE:
#   latest   = half-month containing the newest Time_Clock punch (default)
#   previous = most recently completed half-month
#   current  = half-month containing today (may be in progress)
REPORT_PERIOD_MODE=latest
DRY_RUN=false
"""

FIRST_RUN_MSG = """\
===============================================================================
  FIRST-RUN SETUP
===============================================================================
A configuration file has been created at:
    {cfg_path}

Fill in SQL_SERVER, SMTP_*, and REPORT_RECIPIENT, save, then run again.
===============================================================================
"""


# ---------------------------------------------------------------------------
# Half-month date logic
# ---------------------------------------------------------------------------

def month_last_day(year: int, month: int) -> int:
    """Return 28, 29, 30, or 31 for the given calendar month."""
    return calendar.monthrange(year, month)[1]


def half_month_bounds(year: int, month: int, half: int) -> tuple[_dt.date, _dt.date]:
    """Return (start, end) for half 1 (1–15) or half 2 (16–last day)."""
    if half not in (1, 2):
        raise ValueError("half must be 1 or 2")
    last = month_last_day(year, month)
    if half == 1:
        return _dt.date(year, month, 1), _dt.date(year, month, 15)
    return _dt.date(year, month, 16), _dt.date(year, month, last)


def half_containing(d: _dt.date) -> tuple[_dt.date, _dt.date, int]:
    """Return (start, end, half_number) for the half-month containing d."""
    half = 1 if d.day <= 15 else 2
    start, end = half_month_bounds(d.year, d.month, half)
    return start, end, half


def previous_completed_half(today: _dt.date | None = None) -> tuple[_dt.date, _dt.date, int]:
    """Most recently completed half-month.

    - If today is day 1–15  -> previous month's half 2 (16..last)
    - If today is day 16–end -> current month's half 1 (1..15)
    """
    today = today or _dt.date.today()
    if today.day <= 15:
        if today.month == 1:
            y, m = today.year - 1, 12
        else:
            y, m = today.year, today.month - 1
        start, end = half_month_bounds(y, m, 2)
        return start, end, 2
    start, end = half_month_bounds(today.year, today.month, 1)
    return start, end, 1


def period_label(start: _dt.date, end: _dt.date, half: Optional[int] = None) -> str:
    if half is None:
        half = 1 if start.day == 1 else 2
    month_name = start.strftime("%B %Y")
    return f"{month_name} - Half {half} ({start.isoformat()} to {end.isoformat()})"


# ---------------------------------------------------------------------------
# CLI / env helpers
# ---------------------------------------------------------------------------

def _parse_date(s: str) -> _dt.date:
    return _dt.datetime.strptime(s, "%Y-%m-%d").date()


def _parse_month(s: str) -> tuple[int, int]:
    """Accept YYYY-MM."""
    dt = _dt.datetime.strptime(s, "%Y-%m")
    return dt.year, dt.month


def _parse_emails(s: Optional[str]) -> list[str]:
    if not s:
        return []
    out = []
    for chunk in re.split(r"[,;\s]+", s.strip()):
        if chunk and "@" in chunk:
            out.append(chunk)
    return out


def _sanitize_for_filename(s: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", s).strip("_") or "store"


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Bi-weekly (half-month) employee hours report"
    )
    p.add_argument("--start", help="Start date YYYY-MM-DD (with --end)")
    p.add_argument("--end", help="End date YYYY-MM-DD (with --start)")
    p.add_argument(
        "--month",
        help="Month YYYY-MM used with --half (e.g. 2026-07)",
    )
    p.add_argument(
        "--half",
        type=int,
        choices=[1, 2],
        help="Half of month: 1 = days 1–15, 2 = days 16–last",
    )
    p.add_argument(
        "--period",
        choices=["previous", "current", "latest"],
        help="Override REPORT_PERIOD_MODE when no dates are given "
             "(latest = half with newest Time_Clock data)",
    )
    p.add_argument("--store", help="Only run for this Store_ID")
    p.add_argument("--dry-run", action="store_true",
                   help="Generate files but do not send email")
    p.add_argument("--to", help="Override recipient (comma-sep)")
    p.add_argument("--cc", help="CC addresses, comma-separated")
    p.add_argument("--bcc", help="BCC addresses, comma-separated")
    return p.parse_args(argv)


def resolve_period(ns: argparse.Namespace,
                   latest_punch: Optional[_dt.date] = None
                   ) -> tuple[_dt.date, _dt.date, int, str]:
    """Return start, end, half_number, human label.

    When no explicit --start/--end/--half is given:
      latest   -> half containing latest Time_Clock punch date
      current  -> half containing today
      previous -> most recently completed half
    """
    if ns.start or ns.end:
        if not (ns.start and ns.end):
            raise SystemExit("--start and --end must be used together")
        s, e = _parse_date(ns.start), _parse_date(ns.end)
        if s > e:
            raise SystemExit("--start must be <= --end")
        half = 1 if s.day == 1 and e.day == 15 else (2 if s.day == 16 else 0)
        return s, e, half, period_label(s, e, half or None)

    if ns.half is not None:
        if not ns.month:
            today = _dt.date.today()
            year, month = today.year, today.month
        else:
            year, month = _parse_month(ns.month)
        s, e = half_month_bounds(year, month, ns.half)
        return s, e, ns.half, period_label(s, e, ns.half)

    if ns.month and ns.half is None:
        raise SystemExit("--month requires --half 1 or --half 2")

    mode = (ns.period or os.getenv("REPORT_PERIOD_MODE", "latest")).strip().lower()
    if mode not in {"previous", "current", "latest"}:
        print(f"[warn] Invalid REPORT_PERIOD_MODE={mode!r}. Using 'latest'.")
        mode = "latest"

    today = _dt.date.today()
    if mode == "latest":
        if latest_punch is None:
            print("[warn] No Time_Clock punches found; falling back to previous half.")
            s, e, half = previous_completed_half(today)
        else:
            s, e, half = half_containing(latest_punch)
            print(f"[info] Latest Time_Clock punch: {latest_punch} "
                  f"-> using Half {half}")
    elif mode == "current":
        s, e, half = half_containing(today)
    else:
        s, e, half = previous_completed_half(today)
    return s, e, half, period_label(s, e, half)


def ensure_env() -> bool:
    for candidate in _CONFIG_CANDIDATES:
        if candidate.exists():
            load_dotenv(candidate, override=True)
            return True
    try:
        CONFIG_PATH.write_text(CONFIG_TEMPLATE, encoding="utf-8")
    except Exception as e:
        print(f"[ERROR] Could not create {CONFIG_PATH}: {e}")
        return False
    print(FIRST_RUN_MSG.format(cfg_path=CONFIG_PATH))
    try:
        import subprocess
        subprocess.Popen(["notepad.exe", str(CONFIG_PATH)])
    except Exception:
        pass
    return False


def _was_double_clicked() -> bool:
    if not getattr(sys, "frozen", False):
        return False
    try:
        import ctypes
        from ctypes import wintypes

        TH32CS_SNAPPROCESS = 0x00000002

        class PROCESSENTRY32(ctypes.Structure):
            _fields_ = [
                ("dwSize", wintypes.DWORD),
                ("cntUsage", wintypes.DWORD),
                ("th32ProcessID", wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.c_void_p),
                ("th32ModuleID", wintypes.DWORD),
                ("cntThreads", wintypes.DWORD),
                ("th32ParentProcessID", wintypes.DWORD),
                ("pcPriClassBase", wintypes.LONG),
                ("dwFlags", wintypes.DWORD),
                ("szExeFile", ctypes.c_char * 260),
            ]

        kernel32 = ctypes.windll.kernel32
        hSnapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
        if hSnapshot == -1 or hSnapshot is None:
            return len(sys.argv) == 1 and sys.stdout.isatty()

        pe = PROCESSENTRY32()
        pe.dwSize = ctypes.sizeof(PROCESSENTRY32)
        my_pid = os.getpid()
        parent_pid = None
        parent_name = ""

        if kernel32.Process32First(hSnapshot, ctypes.byref(pe)):
            while True:
                if pe.th32ProcessID == my_pid:
                    parent_pid = pe.th32ParentProcessID
                    break
                if not kernel32.Process32Next(hSnapshot, ctypes.byref(pe)):
                    break

        if parent_pid is not None:
            if kernel32.Process32First(hSnapshot, ctypes.byref(pe)):
                while True:
                    if pe.th32ProcessID == parent_pid:
                        parent_name = pe.szExeFile.decode("ansi", errors="ignore").lower()
                        break
                    if not kernel32.Process32Next(hSnapshot, ctypes.byref(pe)):
                        break

        kernel32.CloseHandle(hSnapshot)
        return parent_name == "explorer.exe"
    except Exception:
        return len(sys.argv) == 1 and sys.stdout.isatty()


def _pause_if_double_clicked() -> None:
    if _was_double_clicked():
        try:
            input("\nPress Enter to close this window...")
        except EOFError:
            pass


# ---------------------------------------------------------------------------
# HTML / XLSX rendering (employee hours only)
# ---------------------------------------------------------------------------

def _fmt_money(v) -> str:
    try:
        return f"${float(v):,.2f}"
    except Exception:
        return "$0.00"


def _fmt_qty(v) -> str:
    try:
        f = float(v)
        if f == int(f):
            return f"{int(f):,}"
        return f"{f:,.2f}"
    except Exception:
        return "0"


def _store_name(merchant: dict, store_id: str) -> str:
    for key in ("Store_Description", "Company_Info_1"):
        v = merchant.get(key)
        if v and str(v).strip():
            return str(v).strip()
    return f"Store {store_id}"


def render_employee_html(*, store_id: str, store_name: str, label: str,
                         employees: pd.DataFrame) -> str:
    rows_html = []
    if employees is None or employees.empty:
        body = (
            '<div style="padding:12px;border:1px solid #eef0f3;color:#6b7280;'
            'font-size:13px;">No employee time-clock records for this period.</div>'
        )
    else:
        disp = employees.copy()
        for col in ("First_Clock_In", "Last_Clock_Out"):
            if col in disp.columns:
                disp[col] = disp[col].apply(
                    lambda v: (
                        pd.Timestamp(v).strftime("%Y-%m-%d %H:%M")
                        if pd.notna(v) else ""
                    )
                )
        cols = [
            "Employee_ID", "Total_Shifts", "First_Clock_In", "Last_Clock_Out",
            "Total_Hours_Worked", "Unpaid_Break_Hours", "Paid_Break_Hours",
            "Regular_Wages", "Overtime_Wages", "Total_Wages",
        ]
        cols = [c for c in cols if c in disp.columns]
        money_cols = {"Regular_Wages", "Overtime_Wages", "Total_Wages"}
        qty_cols = {
            "Total_Shifts", "Total_Hours_Worked",
            "Unpaid_Break_Hours", "Paid_Break_Hours",
        }

        head = "".join(
            f'<th style="text-align:left;padding:8px 10px;border-bottom:2px solid #1f3b5b;'
            f'background:#f7faff;font-size:11px;text-transform:uppercase;color:#1f3b5b;">'
            f'{c.replace("_", " ").title()}</th>'
            for c in cols
        )
        for _, r in disp.iterrows():
            tds = []
            for c in cols:
                val = r[c]
                if c in money_cols:
                    cell = _fmt_money(val)
                    align = "right"
                elif c in qty_cols:
                    cell = _fmt_qty(val)
                    align = "right"
                else:
                    cell = "" if pd.isna(val) else str(val)
                    align = "left"
                tds.append(
                    f'<td style="padding:6px 10px;border-bottom:1px solid #eef0f3;'
                    f'text-align:{align};">{cell}</td>'
                )
            rows_html.append("<tr>" + "".join(tds) + "</tr>")

        # Totals
        totals = []
        for c in cols:
            if c == "Employee_ID":
                totals.append(
                    '<td style="padding:8px 10px;border-top:2px solid #1f3b5b;'
                    'font-weight:700;background:#f7faff;">TOTAL</td>'
                )
            elif c in money_cols:
                totals.append(
                    f'<td style="padding:8px 10px;border-top:2px solid #1f3b5b;'
                    f'font-weight:700;background:#f7faff;text-align:right;">'
                    f'{_fmt_money(disp[c].astype(float).sum())}</td>'
                )
            elif c in qty_cols:
                totals.append(
                    f'<td style="padding:8px 10px;border-top:2px solid #1f3b5b;'
                    f'font-weight:700;background:#f7faff;text-align:right;">'
                    f'{_fmt_qty(disp[c].astype(float).sum())}</td>'
                )
            else:
                totals.append(
                    '<td style="padding:8px 10px;border-top:2px solid #1f3b5b;'
                    'background:#f7faff;"></td>'
                )
        rows_html.append("<tr>" + "".join(totals) + "</tr>")

        body = (
            '<table style="border-collapse:collapse;width:100%;font-size:12px;">'
            f'<thead><tr>{head}</tr></thead>'
            f'<tbody>{"".join(rows_html)}</tbody></table>'
        )

    total_hours = 0.0
    total_wages = 0.0
    emp_count = 0
    if employees is not None and not employees.empty:
        emp_count = len(employees)
        if "Total_Hours_Worked" in employees.columns:
            total_hours = float(employees["Total_Hours_Worked"].astype(float).sum())
        if "Total_Wages" in employees.columns:
            total_wages = float(employees["Total_Wages"].astype(float).sum())

    generated = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Bi-Weekly Employee Hours - {store_name} - {label}</title>
</head>
<body style="margin:0;padding:0;background:#f4f5f7;font-family:Segoe UI,Arial,sans-serif;color:#222;">
<div style="max-width:960px;margin:24px auto;background:#fff;border:1px solid #e2e4e8;border-radius:8px;overflow:hidden;">

  <div style="background:#1f3b5b;color:#fff;padding:20px 28px;">
    <div style="font-size:12px;letter-spacing:1px;text-transform:uppercase;opacity:.85;">Bi-Weekly Employee Hours</div>
    <div style="font-size:22px;font-weight:700;margin-top:4px;">{store_name}</div>
    <div style="font-size:14px;opacity:.9;margin-top:2px;">Period: <strong>{label}</strong></div>
  </div>

  <div style="padding:16px 28px;border-bottom:1px solid #eef0f3;font-size:13px;">
    <table style="border-collapse:collapse;width:100%;">
      <tr>
        <td style="padding:10px 12px;border:1px solid #eef0f3;width:33%;">
          <div style="color:#6b7280;font-size:11px;text-transform:uppercase;">Employees</div>
          <div style="font-size:16px;font-weight:700;margin-top:2px;">{emp_count}</div>
        </td>
        <td style="padding:10px 12px;border:1px solid #eef0f3;width:33%;background:#f7faff;">
          <div style="color:#6b7280;font-size:11px;text-transform:uppercase;">Total Hours Worked</div>
          <div style="font-size:16px;font-weight:700;margin-top:2px;">{_fmt_qty(total_hours)}</div>
        </td>
        <td style="padding:10px 12px;border:1px solid #eef0f3;width:33%;">
          <div style="color:#6b7280;font-size:11px;text-transform:uppercase;">Total Wages</div>
          <div style="font-size:16px;font-weight:700;margin-top:2px;">{_fmt_money(total_wages)}</div>
        </td>
      </tr>
    </table>
    <div style="margin-top:10px;color:#6b7280;font-size:12px;">
      Store ID: {store_id} &nbsp;|&nbsp; Generated: {generated}
    </div>
  </div>

  <div style="padding:16px 28px 24px 28px;">
    <h3 style="margin:0 0 10px 0;font-size:14px;color:#1f3b5b;text-transform:uppercase;letter-spacing:.5px;">
      Employee Time Clock
    </h3>
    {body}
  </div>
</div>
</body>
</html>
"""


def render_employee_xlsx(employees: pd.DataFrame, path: str,
                         *, store_id: str, store_name: str, label: str) -> None:
    with pd.ExcelWriter(path, engine="xlsxwriter") as writer:
        wb = writer.book
        money_fmt = wb.add_format({"num_format": "$#,##0.00"})
        qty_fmt = wb.add_format({"num_format": "#,##0.##"})
        header_fmt = wb.add_format({
            "bold": True, "bg_color": "#1f3b5b", "font_color": "#ffffff",
            "border": 1,
        })

        summary = pd.DataFrame([
            ("Store ID", store_id),
            ("Store Name", store_name),
            ("Period", label),
            ("Generated", _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")),
            ("Employee Count", 0 if employees is None or employees.empty else len(employees)),
            ("Total Hours Worked",
             0.0 if employees is None or employees.empty
             else float(employees.get("Total_Hours_Worked", pd.Series(dtype=float)).astype(float).sum())),
            ("Total Wages",
             0.0 if employees is None or employees.empty
             else float(employees.get("Total_Wages", pd.Series(dtype=float)).astype(float).sum())),
        ], columns=["Metric", "Value"])
        summary.to_excel(writer, sheet_name="Summary", index=False)
        ws = writer.sheets["Summary"]
        ws.set_column(0, 0, 24)
        ws.set_column(1, 1, 48)

        df = employees if employees is not None else pd.DataFrame()
        df.to_excel(writer, sheet_name="Employees", index=False)
        ws2 = writer.sheets["Employees"]
        if df.empty:
            ws2.write(0, 0, "No data", header_fmt)
            return
        money_cols = {"Regular_Wages", "Overtime_Wages", "Total_Wages"}
        qty_cols = {
            "Total_Shifts", "Total_Hours_Worked",
            "Unpaid_Break_Hours", "Paid_Break_Hours",
        }
        for col_idx, col in enumerate(df.columns):
            ws2.write(0, col_idx, col, header_fmt)
            width = max(12, min(40, len(str(col)) + 2))
            if col in money_cols:
                ws2.set_column(col_idx, col_idx, max(width, 14), money_fmt)
            elif col in qty_cols:
                ws2.set_column(col_idx, col_idx, max(width, 12), qty_fmt)
            else:
                ws2.set_column(col_idx, col_idx, width)


# ---------------------------------------------------------------------------
# Per-store generation
# ---------------------------------------------------------------------------

def generate_for_store(conn, merchant_row: dict, start: _dt.date, end: _dt.date,
                       label: str, *, dry_run: bool,
                       override_to: Optional[list[str]],
                       cc: list[str], bcc: list[str],
                       smtp_cfg: Optional[report_mailer.SmtpConfig]) -> dict:
    store_id = str(merchant_row.get("Store_ID") or "").strip()
    store_name = _store_name(merchant_row, store_id)
    employees = report_db.fetch_employee_records(conn, store_id, start, end)

    out_dir = (
        OUTPUT_ROOT
        / f"{start.isoformat()}_to_{end.isoformat()}"
        / _sanitize_for_filename(store_id)
    )
    out_dir.mkdir(parents=True, exist_ok=True)

    base = (
        f"biweekly_hours_{_sanitize_for_filename(store_id)}_"
        f"{start.isoformat()}_to_{end.isoformat()}"
    )
    html_path = out_dir / f"{base}.html"
    xlsx_path = out_dir / f"{base}.xlsx"
    csv_path = out_dir / f"{base}_employees.csv"

    html = render_employee_html(
        store_id=store_id, store_name=store_name, label=label, employees=employees,
    )
    html_path.write_text(html, encoding="utf-8")
    render_employee_xlsx(
        employees, str(xlsx_path),
        store_id=store_id, store_name=store_name, label=label,
    )
    employees.to_csv(csv_path, index=False, encoding="utf-8-sig")

    config_recipient = _parse_emails(os.getenv("REPORT_RECIPIENT", ""))
    recipients = list(override_to) if override_to else list(config_recipient)
    recipients = [r for r in recipients if r]

    total_hours = (
        float(employees["Total_Hours_Worked"].astype(float).sum())
        if not employees.empty and "Total_Hours_Worked" in employees.columns
        else 0.0
    )
    emp_count = 0 if employees.empty else len(employees)

    status = {
        "store_id": store_id,
        "store_name": store_name,
        "html_path": str(html_path),
        "xlsx_path": str(xlsx_path),
        "csv_path": str(csv_path),
        "recipients": recipients,
        "employee_count": emp_count,
        "total_hours": total_hours,
        "sent": False,
        "skipped_reason": None,
    }

    if not recipients:
        status["skipped_reason"] = (
            "REPORT_RECIPIENT is not set in config.env (or use --to for testing)"
        )
        return status

    if dry_run or smtp_cfg is None:
        status["skipped_reason"] = "dry-run"
        return status

    subject = f"Bi-Weekly Employee Hours - {store_name} - {label}"
    job = report_mailer.EmailJob(
        to=list(recipients),
        cc=list(cc),
        bcc=list(bcc),
        subject=subject,
        html_body=html,
        attachments=[str(xlsx_path), str(csv_path)],
    )
    report_mailer.send(smtp_cfg, job)
    status["sent"] = True
    return status


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

class TeeLogger:
    def __init__(self, terminal, log_file):
        self.terminal = terminal
        self.log_file = log_file

    def write(self, message):
        self.terminal.write(message)
        if self.log_file:
            try:
                self.log_file.write(message)
                self.log_file.flush()
            except Exception:
                pass

    def flush(self):
        self.terminal.flush()
        if self.log_file:
            try:
                self.log_file.flush()
            except Exception:
                pass


def main(argv: Optional[list[str]] = None) -> int:
    log_path = SCRIPT_DIR / "biweekly_report_run.log"
    log_file = None
    try:
        if log_path.exists() and log_path.stat().st_size > 5 * 1024 * 1024:
            log_path.write_text("[log rotated]\n", encoding="utf-8")
        log_file = open(log_path, "a", encoding="utf-8")
        now_str = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_file.write(f"\n--- Run started at {now_str} ---\n")
        log_file.flush()
    except Exception as e:
        print(f"[warn] Could not open log file {log_path}: {e}")

    orig_stdout, orig_stderr = sys.stdout, sys.stderr
    if log_file:
        sys.stdout = TeeLogger(orig_stdout, log_file)
        sys.stderr = TeeLogger(orig_stderr, log_file)

    try:
        return _main_impl(argv)
    finally:
        if log_file:
            try:
                now_str = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                log_file.write(f"--- Run ended at {now_str} ---\n")
                log_file.flush()
                log_file.close()
            except Exception:
                pass
            sys.stdout = orig_stdout
            sys.stderr = orig_stderr


def _main_impl(argv: Optional[list[str]] = None) -> int:
    ns = parse_args(argv)

    if not ensure_env():
        _pause_if_double_clicked()
        return 2

    dry_run = ns.dry_run or (
        os.getenv("DRY_RUN", "false").strip().lower() in ("1", "true", "yes", "on")
    )

    override_to = _parse_emails(ns.to) if ns.to else None
    cc = _parse_emails(ns.cc)
    bcc = _parse_emails(ns.bcc)

    smtp_cfg: Optional[report_mailer.SmtpConfig] = None
    if not dry_run:
        smtp_cfg = report_mailer.SmtpConfig.from_env()
        smtp_err = smtp_cfg.validate()
        if smtp_err:
            print(f"[warn] SMTP is not configured ({smtp_err}). "
                  "Switching to dry-run mode.")
            dry_run = True
            smtp_cfg = None

    processed: list[dict] = []
    sent_count = 0
    skipped: list[dict] = []

    try:
        with report_db.open_connection() as conn:
            needs_latest = not (ns.start or ns.end or ns.half is not None)
            latest_punch = None
            if needs_latest:
                latest_punch = report_db.fetch_latest_timeclock_date(
                    conn, store_id=ns.store,
                )

            start, end, half, label = resolve_period(ns, latest_punch=latest_punch)
            last_day = month_last_day(end.year, end.month)

            print("=== Bi-Weekly Employee Hours Report ===")
            print(f"Database : {os.getenv('SQL_SERVER', '')} / {os.getenv('SQL_DATABASE', '')}")
            print(f"Period   : {label}")
            print(f"Days     : {start.day} to {end.day}  (month has {last_day} days)")
            print(f"Mode     : {'DRY RUN (no email)' if dry_run else 'SEND EMAILS'}")
            if ns.store:
                print(f"Store    : {ns.store}")
            print()

            merchants = report_db.fetch_merchants(conn, store_id=ns.store)
            if merchants.empty:
                print("No merchant rows found in dbo.Setup. Nothing to do.")
                return 1

            for _, row in merchants.iterrows():
                mdict = row.to_dict()
                store_id = str(mdict.get("Store_ID") or "").strip()
                try:
                    status = generate_for_store(
                        conn, mdict, start, end, label,
                        dry_run=dry_run, override_to=override_to,
                        cc=cc, bcc=bcc, smtp_cfg=smtp_cfg,
                    )
                except Exception as e:
                    msg = f"{type(e).__name__}: {e}"
                    print(f"  [ERROR] Store {store_id}: {msg}")
                    skipped.append({"store_id": store_id, "reason": msg})
                    continue

                processed.append(status)
                tag = "DRY" if dry_run else ("SENT" if status["sent"] else "SKIP")
                print(
                    f"  [{tag}] Store {status['store_id']:<8} "
                    f"{status['store_name'][:28]:<28} "
                    f"emps={status['employee_count']:<4} "
                    f"hours={status['total_hours']:>8,.2f} "
                    f"-> {status['recipients'] or status['skipped_reason']}"
                )
                if status["sent"]:
                    sent_count += 1
                elif status["skipped_reason"] and status["skipped_reason"] != "dry-run":
                    skipped.append({
                        "store_id": status["store_id"],
                        "reason": status["skipped_reason"],
                    })

            if processed and all(int(p.get("employee_count") or 0) == 0 for p in processed):
                print()
                print("WARNING: 0 employee time-clock rows for this period.")
                if latest_punch:
                    print(f"         Newest punch in DB is {latest_punch}.")
                print("         Try:  --half 1 --month YYYY-MM")
                print("           or: --period latest")

    except Exception as e:
        print(f"[FATAL] {type(e).__name__}: {e}")
        return 3

    print()
    print("=== Summary ===")
    print(f"Stores processed: {len(processed)}")
    print(f"Emails sent:      {0 if dry_run else sent_count}"
          + (" -- DRY RUN" if dry_run else ""))
    print(f"Stores skipped:   {len(skipped)}")
    for s in skipped:
        print(f"  - {s['store_id']}: {s['reason']}")

    if processed:
        # start/end always set when processed non-empty
        out_folder = OUTPUT_ROOT / f"{start.isoformat()}_to_{end.isoformat()}"
        print()
        print(f"Reports saved under: {out_folder}")
        print(f"Preview HTML:        {processed[0]['html_path']}")

    _pause_if_double_clicked()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as _e:
        print(f"\n[FATAL] {type(_e).__name__}: {_e}")
        _pause_if_double_clicked()
        raise
