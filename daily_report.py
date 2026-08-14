"""Daily sales report generator for pcAmerica CRE (cresqlvick).

Runs end-to-end on Windows:
    1. Reads config.env / .env (python-dotenv) for DB + SMTP settings.
    2. Connects to SQL Server via pyodbc (Windows Auth by default).
    3. For each Store_ID in dbo.Setup it builds KPIs, breakdowns, and a
       full itemized transaction list for the requested date range
       (all departments/items from the database).
    4. Renders an HTML email body + an XLSX workbook + a CSV.
    5. Emails each report only to REPORT_RECIPIENT (or --to), not dbo.Setup,
       unless --dry-run is set (or DRY_RUN=true in .env).

Usage:
    python daily_report.py
    python daily_report.py --date 2026-04-21
    python daily_report.py --start 2026-04-01 --end 2026-04-21
    python daily_report.py --store 1001
    python daily_report.py --dry-run
    python daily_report.py --to someone@example.com
"""

from __future__ import annotations

import argparse
import datetime as _dt
import os
import re
import sys
import warnings
from pathlib import Path
from typing import Optional

warnings.filterwarnings("ignore", message="pandas only supports SQLAlchemy")

from dotenv import load_dotenv

import report_db
import report_render
from report_render import ReportBundle
import report_mailer


def _was_double_clicked() -> bool:
    """Heuristic: check if the parent process is explorer.exe to see if the user double-clicked us."""
    if not getattr(sys, "frozen", False):
        return False
    try:
        import ctypes
        import os
        from ctypes import wintypes

        TH32CS_SNAPPROCESS = 0x00000002

        class PROCESSENTRY32(ctypes.Structure):
            _fields_ = [
                ('dwSize', wintypes.DWORD),
                ('cntUsage', wintypes.DWORD),
                ('th32ProcessID', wintypes.DWORD),
                ('th32DefaultHeapID', ctypes.c_void_p),
                ('th32ModuleID', wintypes.DWORD),
                ('cntThreads', wintypes.DWORD),
                ('th32ParentProcessID', wintypes.DWORD),
                ('pcPriClassBase', wintypes.LONG),
                ('dwFlags', wintypes.DWORD),
                ('szExeFile', ctypes.c_char * 260)
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
                        parent_name = pe.szExeFile.decode('ansi', errors='ignore').lower()
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


def _app_dir() -> Path:
    """Folder that holds the config file and report outputs.

    - When running as a PyInstaller-frozen .exe, this is the folder that
      contains the .exe (so each merchant can edit config.env next to it).
    - When running from source, this is the folder of daily_report.py.
    """
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


SCRIPT_DIR = _app_dir()
OUTPUT_ROOT = SCRIPT_DIR / "daily_reports"

# Config file is loaded from the first existing path. `config.env` is the
# merchant-friendly name; `.env` is kept for backwards compatibility.
CONFIG_PATH = SCRIPT_DIR / "config.env"
_CONFIG_CANDIDATES = (
    CONFIG_PATH,
    SCRIPT_DIR / ".env",
)


# Config template that is written to disk on first run if no config.env
# exists next to the exe. Keeps the exe truly single-file -- no need to
# ship a separate .example file.
CONFIG_TEMPLATE = """\
# ------------------------------------------------------------------
# Daily Sales Report - per-merchant configuration
# Edit this file, save, then re-run DailySalesReport.exe
# ------------------------------------------------------------------
#
# Keys read by the program (only these matter):
#   SQL_SERVER, SQL_DATABASE, SQL_AUTH, SQL_USER, SQL_PASSWORD
#   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_FROM, SMTP_USE_TLS
#   REPORT_RECIPIENT   (required for email: comma-separated; Setup DB emails ignored)
#   SMS_RECIPIENTS     (optional; comma-separated email-to-SMS gateways)
#   REPORT_DATE_MODE   (yesterday | today | latest)
#   DRY_RUN            (true|false)
#
# SQL_SERVER: if your instance has a backslash (e.g. Harshil\\pcamerica),
# either quote the value or double each backslash, e.g.:
#   SQL_SERVER="Harshil\\pcamerica"
#   SQL_SERVER=Harshil\\\\pcamerica
#
# SMTP_PASSWORD: Gmail App Passwords are 16 characters; spaces are OK and
# will be removed automatically before login.

# --- SQL Server (pcAmerica CRE) ---
# This PC's SQL instance. Common values:
#   .\\pcamerica
#   LOCALHOST\\pcamerica
#   <COMPUTERNAME>\\pcamerica
SQL_SERVER=LOCALHOST\\pcamerica
SQL_DATABASE=cresqlvick
SQL_AUTH=windows
SQL_USER=
SQL_PASSWORD=

# --- SMTP (outgoing email) ---
# For Gmail: SMTP_PASSWORD must be a Google App Password:
#   https://myaccount.google.com/apppasswords
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your.address@gmail.com
SMTP_PASSWORD=your_google_app_password
SMTP_FROM=Daily Reports <your.address@gmail.com>
SMTP_USE_TLS=true

# --- Recipient ---
# REQUIRED for sending email (comma-separated). Every store report goes ONLY
# to these addresses. dbo.Setup store email fields are NOT used.
REPORT_RECIPIENT=owner@example.com

# --- SMS via Email-to-Text gateway (optional) ---
# Sends a short summary text after each report email.
# Format: <10-digit-number>@<carrier-gateway>
# Common gateways:
#   Ultra Mobile / T-Mobile : number@mailmymobile.net
#   AT&T                    : number@txt.att.net
#   Verizon                 : number@vtext.com
# Leave blank to disable SMS.
SMS_RECIPIENTS=

# --- Other ---
# Default date behavior when no --date/--start/--end is passed:
#   latest     -> most recent sales date found in SQL
#   yesterday  -> calendar yesterday
#   today      -> calendar today
REPORT_DATE_MODE=yesterday
DRY_RUN=false
"""


FIRST_RUN_MSG = """\
===============================================================================
  FIRST-RUN SETUP
===============================================================================
A configuration file has been created at:
    {cfg_path}

Please fill in:
    SQL_SERVER       (this PC's SQL Server instance, e.g. LOCALHOST\\pcamerica)
    SMTP_USER        (Gmail address)
    SMTP_PASSWORD    (Google APP PASSWORD - https://myaccount.google.com/apppasswords)
    SMTP_FROM        (e.g. "Daily Reports <you@gmail.com>")
    REPORT_RECIPIENT (comma-separated; only these addresses receive reports)

It will be opened in Notepad now. Save and close Notepad, then run
DailySalesReport.exe again.
===============================================================================
"""


def _parse_date(s: str) -> _dt.date:
    return _dt.datetime.strptime(s, "%Y-%m-%d").date()


def _parse_emails(s: Optional[str]) -> list[str]:
    if not s:
        return []
    out = []
    for chunk in re.split(r"[,;\s]+", s.strip()):
        if chunk and "@" in chunk:
            out.append(chunk)
    return out


def _parse_sms_recipients() -> list[str]:
    """Return SMS gateway addresses from SMS_RECIPIENTS env var."""
    return _parse_emails(os.getenv("SMS_RECIPIENTS", ""))


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Daily sales report (pcAmerica CRE)")
    p.add_argument("--date", help="Single report date YYYY-MM-DD (defaults to yesterday)")
    p.add_argument("--start", help="Start date YYYY-MM-DD (with --end for range)")
    p.add_argument("--end", help="End date YYYY-MM-DD (with --start for range)")
    p.add_argument("--store", help="Only run for this Store_ID")
    p.add_argument("--dry-run", action="store_true",
                   help="Generate files but do not send email")
    p.add_argument("--to", help="Override recipient (comma-sep). Useful for testing.")
    p.add_argument("--cc", help="CC addresses, comma-separated")
    p.add_argument("--bcc", help="BCC addresses, comma-separated")
    p.add_argument("--sections", help="Comma-separated list of active sections to include (e.g. kpis,departments,top_items)")
    return p.parse_args(argv)


def resolve_active_sections(ns: Optional[argparse.Namespace] = None) -> set[str]:
    if ns and ns.sections:
        return report_render.normalize_active_sections(ns.sections)
    env_sec = os.getenv("REPORT_SECTIONS", "")
    if env_sec.strip():
        return report_render.normalize_active_sections(env_sec)
    return set(report_render.DEFAULT_SECTIONS)


def resolve_date_range(ns: argparse.Namespace) -> tuple[_dt.date, _dt.date]:
    if ns.start or ns.end:
        if not (ns.start and ns.end):
            raise SystemExit("--start and --end must be used together")
        s, e = _parse_date(ns.start), _parse_date(ns.end)
        if s > e:
            raise SystemExit("--start must be <= --end")
        return s, e
    if ns.date:
        d = _parse_date(ns.date)
        return d, d
    y = _dt.date.today() - _dt.timedelta(days=1)
    return y, y


def _resolve_report_date_mode() -> str:
    # Default behavior: yesterday's full-day report.
    # This avoids sending a partial "today" report when the script is run during business hours.
    mode = os.getenv("REPORT_DATE_MODE", "yesterday").strip().lower()
    if mode not in {"latest", "yesterday", "today"}:
        print(f"[warn] Invalid REPORT_DATE_MODE={mode!r}. Falling back to 'yesterday'.")
        return "yesterday"
    return mode


def ensure_env() -> bool:
    """Return True if a config file was found and loaded.

    First-run behavior: if no config exists yet, seed one from the embedded
    template next to the exe, open it in Notepad, and return False so the
    caller can exit gracefully.
    """
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


def _sanitize_for_filename(s: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", s).strip("_") or "store"


def build_report_bundle(conn, store_id: str, merchant: dict,
                        start: _dt.date, end: _dt.date) -> ReportBundle:
    return ReportBundle(
        store_id=store_id,
        merchant=merchant,
        start=start, end=end,
        kpis=report_db.fetch_invoice_kpis(conn, store_id, start, end),
        by_department=report_db.fetch_sales_by_department(conn, store_id, start, end),
        by_fixed_tax=report_db.fetch_sales_by_fixed_tax(conn, store_id, start, end),
        top_items=report_db.fetch_top_items(conn, store_id, start, end),
        by_hour=report_db.fetch_sales_by_hour(conn, store_id, start, end),
        by_payment=report_db.fetch_payment_breakdown(conn, store_id, start, end),
        transactions=report_db.fetch_itemized_transactions(conn, store_id, start, end),
        employees=report_db.fetch_employee_records(conn, store_id, start, end),
        audit_events=report_db.fetch_audit_events(conn, store_id, start, end),
    )


def _date_folder_name(start: _dt.date, end: _dt.date) -> str:
    if start == end:
        return start.isoformat()
    return f"{start.isoformat()}_to_{end.isoformat()}"


def generate_for_store(conn, merchant_row: dict, start: _dt.date, end: _dt.date,
                       *, dry_run: bool, override_to: Optional[list[str]],
                       cc: list[str], bcc: list[str],
                       smtp_cfg: Optional[report_mailer.SmtpConfig],
                       active_sections: Optional[set[str]] = None) -> dict:
    act = report_render.normalize_active_sections(active_sections)
    store_id = str(merchant_row.get("Store_ID") or "").strip()
    bundle = build_report_bundle(conn, store_id, merchant_row, start, end)

    out_dir = OUTPUT_ROOT / _date_folder_name(start, end) / _sanitize_for_filename(store_id)
    out_dir.mkdir(parents=True, exist_ok=True)

    base = f"daily_sales_{_sanitize_for_filename(store_id)}_{_date_folder_name(start, end)}"
    html_path = out_dir / f"{base}.html"
    xlsx_path = out_dir / f"{base}.xlsx"
    csv_path = out_dir / f"{base}_transactions.csv"
    emp_csv_path = out_dir / f"{base}_employees.csv"
    voids_csv_path = out_dir / f"{base}_voids.csv"
    price_csv_path = out_dir / f"{base}_price_changes.csv"
    deletes_csv_path = out_dir / f"{base}_deletes.csv"

    html = report_render.render_html(bundle, active_sections=act)
    html_path.write_text(html, encoding="utf-8")

    attach_xlsx = os.getenv("ATTACH_XLSX", "true").lower() in ("true", "1", "yes")
    attach_csv = os.getenv("ATTACH_CSV", "true").lower() in ("true", "1", "yes")

    attachments = []
    if attach_xlsx:
        report_render.render_xlsx(bundle, str(xlsx_path), active_sections=act)
        attachments.append(str(xlsx_path))

    if attach_csv:
        if "transactions" in act:
            bundle.transactions.to_csv(csv_path, index=False, encoding="utf-8-sig")
            attachments.append(str(csv_path))
        if "employees" in act:
            bundle.employees.to_csv(emp_csv_path, index=False, encoding="utf-8-sig")
            attachments.append(str(emp_csv_path))
        if "voids" in act:
            report_render.slice_audit_events(bundle.audit_events, "Void").to_csv(
                voids_csv_path, index=False, encoding="utf-8-sig"
            )
            attachments.append(str(voids_csv_path))
        if "price_changes" in act:
            report_render.slice_audit_events(bundle.audit_events, "Price Change").to_csv(
                price_csv_path, index=False, encoding="utf-8-sig"
            )
            attachments.append(str(price_csv_path))
        if "deletes" in act:
            report_render.slice_audit_events(bundle.audit_events, "Deleted").to_csv(
                deletes_csv_path, index=False, encoding="utf-8-sig"
            )
            attachments.append(str(deletes_csv_path))

    # Recipients: config only (dbo.Setup store emails are never used).
    # Priority: --to CLI flag > REPORT_RECIPIENT in config.env
    config_recipient = _parse_emails(os.getenv("REPORT_RECIPIENT", ""))
    if override_to:
        recipients = list(override_to)
    else:
        recipients = list(config_recipient)
    recipients = [r for r in recipients if r]

    status = {
        "store_id": store_id,
        "store_name": bundle.store_name,
        "html_path": str(html_path),
        "xlsx_path": str(xlsx_path) if attach_xlsx else None,
        "csv_path": str(csv_path) if "transactions" in act and attach_csv else None,
        "employees_csv_path": str(emp_csv_path) if "employees" in act and attach_csv else None,
        "voids_csv_path": str(voids_csv_path) if "voids" in act and attach_csv else None,
        "price_changes_csv_path": str(price_csv_path) if "price_changes" in act and attach_csv else None,
        "deletes_csv_path": str(deletes_csv_path) if "deletes" in act and attach_csv else None,
        "recipients": recipients,
        "invoice_count": int(bundle.kpis.iloc[0]["invoice_count"])
                         if not bundle.kpis.empty else 0,
        "gross_sales": float(bundle.kpis.iloc[0]["gross_sales"])
                       if not bundle.kpis.empty else 0.0,
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

    subject = f"Daily Sales Report — {bundle.store_name} — {bundle.date_label}"
    job = report_mailer.EmailJob(
        to=list(recipients),
        cc=list(cc),
        bcc=list(bcc),
        subject=subject,
        html_body=html,
        attachments=attachments,
    )
    report_mailer.send(smtp_cfg, job)
    status["sent"] = True

    sms_recipients = _parse_sms_recipients()
    if sms_recipients:
        invoice_count = status["invoice_count"]
        gross = status["gross_sales"]
        sms_text = (
            f"Sales Report - {bundle.store_name}\n"
            f"Date: {bundle.date_label}\n"
            f"Invoices: {invoice_count}\n"
            f"Net Sales: ${gross:,.2f}"
        )
        try:
            report_mailer.send_sms_summary(smtp_cfg, sms_recipients, sms_text)
            print(f"  [SMS ] Sent to {sms_recipients}")
        except Exception as sms_err:
            print(f"  [SMS ] WARNING: could not send SMS: {sms_err}")

    return status


class TeeLogger(object):
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
    log_path = SCRIPT_DIR / "daily_report_run.log"
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

    orig_stdout = sys.stdout
    orig_stderr = sys.stderr
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

    have_env = ensure_env()
    if not have_env:
        # First-run setup: config was just created. Exit so the merchant
        # can edit it, then re-run.
        _pause_if_double_clicked()
        return 2

    dry_run = ns.dry_run or (
        os.getenv("DRY_RUN", "false").strip().lower() in ("1", "true", "yes", "on")
    )

    start, end = resolve_date_range(ns)
    used_default_day = not (ns.date or ns.start or ns.end)
    report_date_mode = _resolve_report_date_mode()
    if used_default_day and report_date_mode == "today":
        start = _dt.date.today()
        end = start
    elif used_default_day and report_date_mode == "yesterday":
        start = _dt.date.today() - _dt.timedelta(days=1)
        end = start
    override_to = _parse_emails(ns.to) if ns.to else None
    cc = _parse_emails(ns.cc)
    bcc = _parse_emails(ns.bcc)

    smtp_cfg: Optional[report_mailer.SmtpConfig] = None
    if not dry_run:
        smtp_cfg = report_mailer.SmtpConfig.from_env()
        smtp_err = smtp_cfg.validate()
        if smtp_err:
            print(f"[warn] SMTP is not configured ({smtp_err}). "
                  "Switching to dry-run mode (files will be generated but no email sent).")
            dry_run = True
            smtp_cfg = None

    active_sections = resolve_active_sections(ns)
    print(f"=== Daily Sales Report ===")
    print(f"Database : {os.getenv('SQL_SERVER', 'harshil\\pcamerica')} / "
          f"{os.getenv('SQL_DATABASE', 'cresqlvick')}")
    print(f"Period   : {start} -> {end}")
    print(f"Mode     : {'DRY RUN (no email)' if dry_run else 'SEND EMAILS'}")
    print(f"Sections : {', '.join(sorted(active_sections))}")
    if override_to:
        print(f"Override : sending all reports to {override_to}")
    if ns.store:
        print(f"Store    : {ns.store}")
    print()

    processed: list[dict] = []
    sent_count = 0
    skipped: list[dict] = []

    try:
        with report_db.open_connection() as conn:
            if used_default_day and report_date_mode == "latest":
                latest_sales_date = report_db.fetch_latest_sales_date(conn, store_id=ns.store)
                if latest_sales_date and latest_sales_date != start:
                    print(f"[info] REPORT_DATE_MODE=latest; switching from default day "
                          f"({start}) to latest sales date ({latest_sales_date}).")
                    start = latest_sales_date
                    end = latest_sales_date

            merchants = report_db.fetch_merchants(conn, store_id=ns.store)
            if merchants.empty:
                print("No merchant rows found in dbo.Setup. Nothing to do.")
                return 1

            for _, row in merchants.iterrows():
                mdict = row.to_dict()
                store_id = str(mdict.get("Store_ID") or "").strip()
                try:
                    status = generate_for_store(
                        conn, mdict, start, end,
                        dry_run=dry_run, override_to=override_to,
                        cc=cc, bcc=bcc, smtp_cfg=smtp_cfg,
                        active_sections=active_sections,
                    )
                except Exception as e:
                    msg = f"{type(e).__name__}: {e}"
                    print(f"  [ERROR] Store {store_id}: {msg}")
                    skipped.append({"store_id": store_id, "reason": msg})
                    continue

                processed.append(status)

                tag = "DRY" if dry_run else ("SENT" if status["sent"] else "SKIP")
                line = (f"  [{tag}] Store {status['store_id']:<8} "
                        f"{status['store_name'][:30]:<30} "
                        f"invoices={status['invoice_count']:<5} "
                        f"net=${status['gross_sales']:>10,.2f} "
                        f"-> {status['recipients'] or status['skipped_reason']}")
                print(line)

                if status["sent"]:
                    sent_count += 1
                elif status["skipped_reason"] and status["skipped_reason"] != "dry-run":
                    skipped.append({
                        "store_id": status["store_id"],
                        "reason": status["skipped_reason"],
                    })

    except Exception as e:
        print(f"[FATAL] {type(e).__name__}: {e}")
        return 3

    print()
    print("=== Summary ===")
    print(f"Stores processed: {len(processed)}")
    if dry_run:
        print(f"Emails sent:      0 -- DRY RUN")
    else:
        print(f"Emails sent:      {sent_count}")
    if skipped:
        print(f"Stores skipped:   {len(skipped)}")
        for s in skipped:
            print(f"  - {s['store_id']}: {s['reason']}")
    else:
        print("Stores skipped:   0")

    if processed:
        out_root = OUTPUT_ROOT / _date_folder_name(start, end)
        print()
        print(f"Reports saved under: {out_root}")
        first = processed[0]
        print(f"Preview HTML:        {first['html_path']}")

    total_invoices = sum(int(p.get("invoice_count") or 0) for p in processed)
    if total_invoices == 0:
        print()
        print("WARNING: 0 invoices were found for the selected period.")
        print("         Check SQL_DATABASE in config.env (common value: cresqlvick)")
        print("         or run with --date YYYY-MM-DD for a known business day.")

    if not override_to and not _parse_emails(os.getenv("REPORT_RECIPIENT", "")):
        print()
        print("NOTE: REPORT_RECIPIENT is not set in config.env.")
        print("      Reports are sent ONLY to addresses listed there (comma-separated).")
        print("      dbo.Setup store emails are not used.")

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
