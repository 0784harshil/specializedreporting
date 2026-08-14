"""Specialized Reporting — pcAmerica CRE (Professional Desktop Edition)

A high-performance, enterprise-grade PySide6 desktop application for pcAmerica CRE POS:
  - 100% Single-File Deployment (Only Specialized_Reporting.exe needed!)
  - Self-Bootstrapping: Automatically generates config.env on first launch
  - Dual-Mode Engine: Interactive Studio GUI + Background Scheduled Runner (--scheduled)
  - Branded Specialized Reporting Desktop Application
  - JD Gurus Emblem Icon Integration
  - Integrated GitHub Auto-Updater & Force-Update Engine (updater.py)
  - 100% Native Zero-Console & Zero-Flicker Desktop UI
  - Cryptographic Salted SHA-256 Team Password Protection & Role-Based Access Control
  - Configurable Automated Schedule Time (Default: 07:00 AM) with 1-Click Windows Task Scheduler Sync
  - Dual Authentication: Windows Authentication (Trusted) & SQL Server Authentication (UID/PWD)
  - SQL Server Auto-Discovery & Database Catalog Auto-Fetching
  - Store Metadata & Latest Date Extraction from dbo.Setup / dbo.Invoice_Totals
  - Modular Report Builder with dynamic section filtering (HTML, XLSX, CSV, SMS)
  - Ultra-Fast Instant HTML Preview + 1-Click External Browser Launch
  - Interactive Data Explorer for Transactions, TimeClock, Voids, Price Overrides, and Department Sales
  - Asynchronous background QThread workers for 100% UI responsiveness
  - Full bidirectional persistence with config.env / .env
"""

from __future__ import annotations

import datetime as _dt
import os
import re
import subprocess
import sys
import warnings
import webbrowser
from pathlib import Path
from typing import Optional, Set

warnings.filterwarnings("ignore")

from dotenv import load_dotenv

# PySide6 UI Imports
from PySide6.QtCore import (
    QDate,
    QObject,
    QSize,
    QTime,
    Qt,
    QThread,
    Signal,
)
from PySide6.QtGui import QFont, QIcon, QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QComboBox,
    QDateEdit,
    QDialog,
    QFileDialog,
    QFrame,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QRadioButton,
    QScrollArea,
    QSplitter,
    QStackedWidget,
    QTabWidget,
    QTableWidget,
    QTableWidgetItem,
    QTextBrowser,
    QTimeEdit,
    QVBoxLayout,
    QWidget,
)

import auth_guard
import report_db
import report_mailer
import report_render
import updater
from report_render import AVAILABLE_SECTIONS, DEFAULT_SECTIONS, ReportBundle

# ---------------------------------------------------------------------------
# Path & Environment Resolution
# ---------------------------------------------------------------------------

def get_base_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent

BASE_DIR = get_base_dir()
CONFIG_FILE = BASE_DIR / "config.env"
DOTENV_FILE = BASE_DIR / ".env"
OUTPUT_ROOT = BASE_DIR / "daily_reports"
ICON_PATH = BASE_DIR / "app_icon.png"
ICO_PATH = BASE_DIR / "app_icon.ico"


def load_app_env() -> dict[str, str]:
    """Loads configuration, automatically creating config.env on first launch if missing."""
    if not CONFIG_FILE.exists() and not DOTENV_FILE.exists():
        default_cfg = {
            "SQL_SERVER": r"Harshil\pcamerica",
            "SQL_DATABASE": "cresqlvick",
            "SQL_AUTH": "sql",
            "SQL_USER": "sa",
            "SQL_PASSWORD": "pcAmer1ca",
            "SMTP_HOST": "smtp.gmail.com",
            "SMTP_PORT": "587",
            "SMTP_USER": "harshilp.job10@gmail.com",
            "SMTP_PASSWORD": "ultb bstt ebjf adrr",
            "SMTP_FROM": "Daily Reports <harshilp.job10@gmail.com>",
            "SMTP_USE_TLS": "true",
            "REPORT_RECIPIENT": "harshil@jdgurus.com",
            "SMS_RECIPIENTS": "",
            "REPORT_DATE_MODE": "yesterday",
            "DRY_RUN": "false",
            "REPORT_SECTIONS": ",".join(DEFAULT_SECTIONS),
            "ATTACH_XLSX": "true",
            "ATTACH_CSV": "true",
            "SCHEDULE_TIME": "07:00",
            "SCHEDULE_ENABLED": "true",
            "GITHUB_REPO": "0784harshil/specializedreporting",
            "AUTO_CHECK_UPDATES": "true",
        }
        save_app_env(default_cfg)
        return default_cfg

    if CONFIG_FILE.exists():
        load_dotenv(CONFIG_FILE, override=True)
    elif DOTENV_FILE.exists():
        load_dotenv(DOTENV_FILE, override=True)
    
    return {
        "SQL_SERVER": os.getenv("SQL_SERVER", r"Harshil\pcamerica"),
        "SQL_DATABASE": os.getenv("SQL_DATABASE", "cresqlvick"),
        "SQL_AUTH": os.getenv("SQL_AUTH", "sql").lower(),
        "SQL_USER": os.getenv("SQL_USER", "sa"),
        "SQL_PASSWORD": os.getenv("SQL_PASSWORD", "pcAmer1ca"),
        "SMTP_HOST": os.getenv("SMTP_HOST", "smtp.gmail.com"),
        "SMTP_PORT": os.getenv("SMTP_PORT", "587"),
        "SMTP_USER": os.getenv("SMTP_USER", "harshilp.job10@gmail.com"),
        "SMTP_PASSWORD": os.getenv("SMTP_PASSWORD", "ultb bstt ebjf adrr"),
        "SMTP_FROM": os.getenv("SMTP_FROM", "Daily Reports <harshilp.job10@gmail.com>"),
        "SMTP_USE_TLS": os.getenv("SMTP_USE_TLS", "true"),
        "REPORT_RECIPIENT": os.getenv("REPORT_RECIPIENT", "harshil@jdgurus.com"),
        "SMS_RECIPIENTS": os.getenv("SMS_RECIPIENTS", ""),
        "REPORT_DATE_MODE": os.getenv("REPORT_DATE_MODE", "yesterday"),
        "DRY_RUN": os.getenv("DRY_RUN", "false"),
        "REPORT_SECTIONS": os.getenv("REPORT_SECTIONS", ",".join(DEFAULT_SECTIONS)),
        "ATTACH_XLSX": os.getenv("ATTACH_XLSX", "true"),
        "ATTACH_CSV": os.getenv("ATTACH_CSV", "true"),
        "SCHEDULE_TIME": os.getenv("SCHEDULE_TIME", "07:00"),
        "SCHEDULE_ENABLED": os.getenv("SCHEDULE_ENABLED", "true"),
        "GITHUB_REPO": os.getenv("GITHUB_REPO", "0784harshil/specializedreporting"),
        "AUTO_CHECK_UPDATES": os.getenv("AUTO_CHECK_UPDATES", "true"),
    }


def save_app_env(cfg: dict[str, str]) -> None:
    lines = [
        "# ===================================================================",
        "# Specialized Reporting Configuration — pcAmerica CRE",
        f"# Updated: {_dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "# ===================================================================",
        "",
        "# --- SQL Server Connection ---",
        f"SQL_SERVER={cfg.get('SQL_SERVER', '')}",
        f"SQL_DATABASE={cfg.get('SQL_DATABASE', 'cresqlvick')}",
        f"SQL_AUTH={cfg.get('SQL_AUTH', 'sql')}",
        f"SQL_USER={cfg.get('SQL_USER', '')}",
        f"SQL_PASSWORD={cfg.get('SQL_PASSWORD', '')}",
        "",
        "# --- SMTP Email Settings ---",
        f"SMTP_HOST={cfg.get('SMTP_HOST', 'smtp.gmail.com')}",
        f"SMTP_PORT={cfg.get('SMTP_PORT', '587')}",
        f"SMTP_USER={cfg.get('SMTP_USER', '')}",
        f"SMTP_PASSWORD={cfg.get('SMTP_PASSWORD', '')}",
        f"SMTP_FROM={cfg.get('SMTP_FROM', 'Daily Reports <you@gmail.com>')}",
        f"SMTP_USE_TLS={cfg.get('SMTP_USE_TLS', 'true')}",
        "",
        "# --- Recipients & Options ---",
        f"REPORT_RECIPIENT={cfg.get('REPORT_RECIPIENT', '')}",
        f"SMS_RECIPIENTS={cfg.get('SMS_RECIPIENTS', '')}",
        f"REPORT_DATE_MODE={cfg.get('REPORT_DATE_MODE', 'yesterday')}",
        f"DRY_RUN={cfg.get('DRY_RUN', 'false')}",
        f"REPORT_SECTIONS={cfg.get('REPORT_SECTIONS', '')}",
        f"ATTACH_XLSX={cfg.get('ATTACH_XLSX', 'true')}",
        f"ATTACH_CSV={cfg.get('ATTACH_CSV', 'true')}",
        "",
        "# --- Automated Daily Schedule ---",
        f"SCHEDULE_TIME={cfg.get('SCHEDULE_TIME', '07:00')}",
        f"SCHEDULE_ENABLED={cfg.get('SCHEDULE_ENABLED', 'true')}",
        "",
        "# --- GitHub Remote Updates ---",
        f"GITHUB_REPO={cfg.get('GITHUB_REPO', '0784harshil/specializedreporting')}",
        f"AUTO_CHECK_UPDATES={cfg.get('AUTO_CHECK_UPDATES', 'true')}",
        "",
    ]
    content = "\n".join(lines)
    CONFIG_FILE.write_text(content, encoding="utf-8")
    DOTENV_FILE.write_text(content, encoding="utf-8")
    load_dotenv(CONFIG_FILE, override=True)


# ---------------------------------------------------------------------------
# Background Async Threads
# ---------------------------------------------------------------------------

class UpdateCheckWorker(QThread):
    check_finished = Signal(object)
    error = Signal(str)

    def __init__(self, github_repo: str):
        super().__init__()
        self.github_repo = github_repo

    def run(self):
        try:
            info = updater.check_for_updates(self.github_repo)
            self.check_finished.emit(info)
        except Exception as e:
            self.error.emit(str(e))


class UpdateDownloadWorker(QThread):
    progress = Signal(int, int)
    complete = Signal(str)
    error = Signal(str)

    def __init__(self, download_url: str, target_path: Path):
        super().__init__()
        self.download_url = download_url
        self.target_path = target_path

    def run(self):
        try:
            def cb(downloaded, total):
                self.progress.emit(downloaded, total)

            updater.download_update_binary(self.download_url, self.target_path, progress_callback=cb)
            self.complete.emit(str(self.target_path))
        except Exception as e:
            self.error.emit(str(e))


class DbFetchWorker(QThread):
    summary_ready = Signal(dict)
    error = Signal(str)
    log_msg = Signal(str)

    def __init__(self, server: str, database: str, auth: str, user: str, pwd: str):
        super().__init__()
        self.server = server
        self.database = database
        self.auth = auth
        self.user = user
        self.pwd = pwd

    def run(self):
        try:
            self.log_msg.emit(f"Connecting to SQL Server: {self.server} (Auth: {self.auth})...")
            with report_db.open_connection(self.server, self.database, self.auth, self.user, self.pwd) as conn:
                self.log_msg.emit("Fetching database catalog & merchant metadata from dbo.Setup...")
                summary = report_db.fetch_server_summary(conn)
                summary["databases"] = report_db.fetch_server_databases(conn)
                self.log_msg.emit(f"Auto-fetch completed: {len(summary.get('stores', []))} store(s) identified.")
                self.summary_ready.emit(summary)
        except Exception as e:
            self.error.emit(str(e))


class ReportGenerateWorker(QThread):
    report_ready = Signal(object, list, dict)
    error = Signal(str)
    progress = Signal(str)
    log_msg = Signal(str)

    def __init__(self, server: str, database: str, auth: str, user: str, pwd: str,
                 store_id: Optional[str], start_date: _dt.date, end_date: _dt.date,
                 active_sections: set[str], attach_xlsx: bool, attach_csv: bool):
        super().__init__()
        self.server = server
        self.database = database
        self.auth = auth
        self.user = user
        self.pwd = pwd
        self.store_id = store_id
        self.start = start_date
        self.end = end_date
        self.active_sections = active_sections
        self.attach_xlsx = attach_xlsx
        self.attach_csv = attach_csv

    def run(self):
        try:
            self.progress.emit("Connecting to SQL Server...")
            self.log_msg.emit(f"Starting report generation for period: {self.start} -> {self.end}")
            
            with report_db.open_connection(self.server, self.database, self.auth, self.user, self.pwd) as conn:
                self.progress.emit("Querying store setup...")
                merchants_df = report_db.fetch_merchants(conn, store_id=self.store_id)
                if merchants_df.empty:
                    self.error.emit(f"No store records found in dbo.Setup (Store ID: {self.store_id or 'ALL'}).")
                    return

                bundles = []
                generated_files = []
                total_invoices = 0
                total_gross = 0.0
                total_cash = 0.0
                total_tax = 0.0

                for idx, (_, row) in enumerate(merchants_df.iterrows(), 1):
                    mdict = row.to_dict()
                    st_id = str(mdict.get("Store_ID") or "").strip()
                    st_name = str(mdict.get("Store_Name") or f"Store {st_id}").strip()
                    
                    self.progress.emit(f"Querying data for {st_name} ({idx}/{len(merchants_df)})...")
                    self.log_msg.emit(f"Fetching tables for Store {st_id} ({st_name})...")
                    
                    bundle = report_render.ReportBundle(
                        store_id=st_id,
                        merchant=mdict,
                        start=self.start,
                        end=self.end,
                        kpis=report_db.fetch_invoice_kpis(conn, st_id, self.start, self.end),
                        by_department=report_db.fetch_sales_by_department(conn, st_id, self.start, self.end),
                        by_fixed_tax=report_db.fetch_sales_by_fixed_tax(conn, st_id, self.start, self.end),
                        top_items=report_db.fetch_top_items(conn, st_id, self.start, self.end),
                        by_hour=report_db.fetch_sales_by_hour(conn, st_id, self.start, self.end),
                        by_payment=report_db.fetch_payment_breakdown(conn, st_id, self.start, self.end),
                        transactions=report_db.fetch_itemized_transactions(conn, st_id, self.start, self.end),
                        employees=report_db.fetch_employee_records(conn, st_id, self.start, self.end),
                        audit_events=report_db.fetch_audit_events(conn, st_id, self.start, self.end),
                    )
                    bundles.append(bundle)

                    date_folder = f"{self.start.isoformat()}" if self.start == self.end else f"{self.start.isoformat()}_to_{self.end.isoformat()}"
                    out_dir = OUTPUT_ROOT / date_folder / st_id
                    out_dir.mkdir(parents=True, exist_ok=True)
                    base_name = f"daily_sales_{st_id}_{date_folder}"
                    
                    html = report_render.render_html(bundle, active_sections=self.active_sections)
                    html_file = out_dir / f"{base_name}.html"
                    html_file.write_text(html, encoding="utf-8")
                    file_bundle = {"store_id": st_id, "html": str(html_file), "xlsx": None, "csvs": []}

                    if self.attach_xlsx:
                        xlsx_file = out_dir / f"{base_name}.xlsx"
                        report_render.render_xlsx(bundle, str(xlsx_file), active_sections=self.active_sections)
                        file_bundle["xlsx"] = str(xlsx_file)

                    if self.attach_csv:
                        if "transactions" in self.active_sections and not bundle.transactions.empty:
                            tx_csv = out_dir / f"{base_name}_transactions.csv"
                            bundle.transactions.to_csv(tx_csv, index=False, encoding="utf-8-sig")
                            file_bundle["csvs"].append(str(tx_csv))
                        if "employees" in self.active_sections and not bundle.employees.empty:
                            emp_csv = out_dir / f"{base_name}_employees.csv"
                            bundle.employees.to_csv(emp_csv, index=False, encoding="utf-8-sig")
                            file_bundle["csvs"].append(str(emp_csv))
                        if "voids" in self.active_sections:
                            v_df = report_render.slice_audit_events(bundle.audit_events, "Void")
                            if not v_df.empty:
                                v_csv = out_dir / f"{base_name}_voids.csv"
                                v_df.to_csv(v_csv, index=False, encoding="utf-8-sig")
                                file_bundle["csvs"].append(str(v_csv))
                        if "price_changes" in self.active_sections:
                            pc_df = report_render.slice_audit_events(bundle.audit_events, "Price Change")
                            if not pc_df.empty:
                                pc_csv = out_dir / f"{base_name}_price_changes.csv"
                                pc_df.to_csv(pc_csv, index=False, encoding="utf-8-sig")
                                file_bundle["csvs"].append(str(pc_csv))
                        if "deletes" in self.active_sections:
                            del_df = report_render.slice_audit_events(bundle.audit_events, "Deleted")
                            if not del_df.empty:
                                del_csv = out_dir / f"{base_name}_deletes.csv"
                                del_df.to_csv(del_csv, index=False, encoding="utf-8-sig")
                                file_bundle["csvs"].append(str(del_csv))

                    generated_files.append(file_bundle)

                    if not bundle.kpis.empty:
                        krow = bundle.kpis.iloc[0]
                        total_invoices += int(krow.get("invoice_count", 0) or 0)
                        total_gross += float(krow.get("gross_sales", 0) or 0)
                        total_cash += float(krow.get("cash_collected", 0) or 0)
                        total_tax += float(krow.get("sales_tax", 0) or 0)

                metrics = {
                    "invoices": total_invoices,
                    "gross_sales": total_gross,
                    "cash_collected": total_cash,
                    "sales_tax": total_tax,
                    "avg_ticket": (total_gross / total_invoices) if total_invoices else 0.0,
                    "store_count": len(bundles),
                }

                self.log_msg.emit(f"Generated {len(bundles)} report(s). Total Invoices: {total_invoices}, Net Sales: ${total_gross:,.2f}")
                self.progress.emit("Reports generated successfully!")
                self.report_ready.emit(bundles, generated_files, metrics)

        except Exception as e:
            self.error.emit(str(e))


class EmailSendWorker(QThread):
    sent_success = Signal(int)
    error = Signal(str)
    log_msg = Signal(str)

    def __init__(self, smtp_cfg: report_mailer.SmtpConfig, bundles: list[ReportBundle],
                 generated_files: list[dict], recipients: list[str], sms_recipients: list[str],
                 active_sections: set[str]):
        super().__init__()
        self.smtp_cfg = smtp_cfg
        self.bundles = bundles
        self.generated_files = generated_files
        self.recipients = recipients
        self.sms_recipients = sms_recipients
        self.active_sections = active_sections

    def run(self):
        try:
            sent_count = 0
            for idx, bundle in enumerate(self.bundles):
                st_id = bundle.store_id
                file_info = next((f for f in self.generated_files if f["store_id"] == st_id), None)
                if not file_info:
                    continue

                html_path = Path(file_info["html"])
                html_body = html_path.read_text(encoding="utf-8")

                attachments = []
                if file_info.get("xlsx") and Path(file_info["xlsx"]).exists():
                    attachments.append(file_info["xlsx"])
                for c in file_info.get("csvs", []):
                    if Path(c).exists():
                        attachments.append(c)

                subject = f"Daily Sales Report — {bundle.store_name} — {bundle.date_label}"
                self.log_msg.emit(f"Dispatching email for Store {st_id} to {len(self.recipients)} recipient(s)...")
                
                job = report_mailer.EmailJob(
                    to=self.recipients,
                    cc=[],
                    bcc=[],
                    subject=subject,
                    html_body=html_body,
                    attachments=attachments,
                )
                report_mailer.send(self.smtp_cfg, job)
                sent_count += 1

                if self.sms_recipients:
                    sms_body = report_render.render_sms(bundle, active_sections=self.active_sections)
                    try:
                        self.log_msg.emit(f"Dispatching SMS text summary to {len(self.sms_recipients)} gateway(s)...")
                        report_mailer.send_sms_summary(self.smtp_cfg, self.sms_recipients, sms_body)
                    except Exception as ex:
                        self.log_msg.emit(f"SMS Gateway Notice: {ex}")

            self.sent_success.emit(sent_count)
        except Exception as e:
            self.error.emit(str(e))


# ---------------------------------------------------------------------------
# Password Authentication Dialog
# ---------------------------------------------------------------------------

class TeamLoginDialog(QDialog):
    def __init__(self, parent=None, is_change_mode=False):
        super().__init__(parent)
        self.is_change_mode = is_change_mode
        self.setWindowTitle("🔐 IT / Support Team Authentication")
        self.setFixedSize(440, 260 if not is_change_mode else 320)
        
        if ICON_PATH.exists():
            self.setWindowIcon(QIcon(str(ICON_PATH)))

        self.setStyleSheet("""
            QDialog {
                background-color: #ffffff;
                font-family: 'Segoe UI Variable Text', 'Segoe UI', sans-serif;
            }
            QLabel {
                color: #0f172a;
                font-size: 13px;
            }
            QLineEdit {
                border: 1px solid #cbd5e1;
                border-radius: 6px;
                padding: 8px 12px;
                font-size: 13px;
            }
            QLineEdit:focus {
                border: 2px solid #2563eb;
            }
            QPushButton {
                background-color: #2563eb;
                color: white;
                font-weight: 600;
                border-radius: 6px;
                padding: 9px 18px;
            }
            QPushButton:hover {
                background-color: #1d4ed8;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 20, 24, 20)
        layout.setSpacing(14)

        title = QLabel("🔐 Admin & Team Access Verification" if not is_change_mode else "🔐 Change Team Master Password")
        title.setStyleSheet("font-size: 16px; font-weight: 800; color: #0f172a;")
        layout.addWidget(title)

        if not is_change_mode:
            sub = QLabel("Enter your team master password to unlock server credentials and settings:")
            sub.setStyleSheet("color: #64748b; font-size: 12px;")
            sub.setWordWrap(True)
            layout.addWidget(sub)

            self.txt_pwd = QLineEdit()
            self.txt_pwd.setEchoMode(QLineEdit.EchoMode.Password)
            self.txt_pwd.setPlaceholderText("Enter Team Password")
            layout.addWidget(self.txt_pwd)

            btn_box = QHBoxLayout()
            self.btn_unlock = QPushButton("🔓 Unlock Studio")
            self.btn_unlock.clicked.connect(self.verify_and_accept)
            self.btn_cancel = QPushButton("Cancel")
            self.btn_cancel.setStyleSheet("background-color: #f1f5f9; color: #475569; border: 1px solid #cbd5e1;")
            self.btn_cancel.clicked.connect(self.reject)

            btn_box.addWidget(self.btn_unlock)
            btn_box.addWidget(self.btn_cancel)
            layout.addLayout(btn_box)

        else:
            sub = QLabel("Update the master password used to protect SQL and SMTP settings:")
            sub.setStyleSheet("color: #64748b; font-size: 12px;")
            layout.addWidget(sub)

            self.txt_current = QLineEdit()
            self.txt_current.setEchoMode(QLineEdit.EchoMode.Password)
            self.txt_current.setPlaceholderText("Current Password")
            layout.addWidget(self.txt_current)

            self.txt_new = QLineEdit()
            self.txt_new.setEchoMode(QLineEdit.EchoMode.Password)
            self.txt_new.setPlaceholderText("New Password (min 4 characters)")
            layout.addWidget(self.txt_new)

            self.txt_confirm = QLineEdit()
            self.txt_confirm.setEchoMode(QLineEdit.EchoMode.Password)
            self.txt_confirm.setPlaceholderText("Confirm New Password")
            layout.addWidget(self.txt_confirm)

            btn_box = QHBoxLayout()
            self.btn_change = QPushButton("💾 Update Password")
            self.btn_change.clicked.connect(self.change_password_and_accept)
            self.btn_cancel = QPushButton("Cancel")
            self.btn_cancel.setStyleSheet("background-color: #f1f5f9; color: #475569; border: 1px solid #cbd5e1;")
            self.btn_cancel.clicked.connect(self.reject)

            btn_box.addWidget(self.btn_change)
            btn_box.addWidget(self.btn_cancel)
            layout.addLayout(btn_box)

    def verify_and_accept(self):
        entered = self.txt_pwd.text().strip()
        if auth_guard.verify_team_password(entered):
            self.accept()
        else:
            QMessageBox.critical(self, "Access Denied", "❌ Incorrect team password. Please try again.")

    def change_password_and_accept(self):
        curr = self.txt_current.text().strip()
        new_p = self.txt_new.text().strip()
        conf = self.txt_confirm.text().strip()

        if not auth_guard.verify_team_password(curr):
            QMessageBox.critical(self, "Verification Failed", "❌ Current password is incorrect.")
            return

        if len(new_p) < 4:
            QMessageBox.warning(self, "Invalid Password", "Password should be at least 4 characters.")
            return

        if new_p != conf:
            QMessageBox.warning(self, "Mismatch", "New password and confirmation do not match.")
            return

        if auth_guard.change_team_password(new_p):
            QMessageBox.information(self, "Password Updated", "✅ Team master password successfully updated!")
            self.accept()
        else:
            QMessageBox.critical(self, "Error", "Failed to update password.")


# ---------------------------------------------------------------------------
# Modern UI Theme Stylesheet
# ---------------------------------------------------------------------------

MODERN_STYLESHEET = """
QMainWindow {
    background-color: #0f172a;
}
QWidget {
    font-family: 'Segoe UI Variable Text', 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
    color: #1e293b;
    font-size: 13px;
}

QFrame#sidebarFrame {
    background-color: #0f172a;
    border-right: 1px solid #1e293b;
}
QListWidget#navSidebar {
    background-color: transparent;
    border: none;
    outline: none;
    padding: 8px;
}
QListWidget#navSidebar::item {
    color: #94a3b8;
    padding: 12px 14px;
    border-radius: 8px;
    font-weight: 600;
    font-size: 13px;
    margin-bottom: 4px;
}
QListWidget#navSidebar::item:hover {
    background-color: #1e293b;
    color: #f8fafc;
}
QListWidget#navSidebar::item:selected {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #2563eb, stop:1 #3b82f6);
    color: #ffffff;
    font-weight: 700;
}

QWidget#contentArea {
    background-color: #f8fafc;
    border-top-left-radius: 12px;
}

QGroupBox {
    background-color: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    margin-top: 14px;
    padding: 16px 14px 14px 14px;
    font-weight: 700;
    font-size: 13px;
    color: #0f172a;
}
QGroupBox::title {
    subcontrol-origin: margin;
    subcontrol-position: top left;
    padding: 0 10px;
    color: #1e293b;
}

QFrame.cardFrame {
    background-color: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
}

QLineEdit, QComboBox, QDateEdit, QTimeEdit {
    border: 1px solid #cbd5e1;
    border-radius: 6px;
    padding: 7px 12px;
    background-color: #ffffff;
    color: #0f172a;
    font-size: 13px;
}
QLineEdit:focus, QComboBox:focus, QDateEdit:focus, QTimeEdit:focus {
    border: 2px solid #2563eb;
    background-color: #ffffff;
}
QLineEdit:disabled, QComboBox:disabled, QDateEdit:disabled, QTimeEdit:disabled {
    background-color: #f1f5f9;
    color: #94a3b8;
    border-color: #e2e8f0;
}

QPushButton {
    background-color: #2563eb;
    color: #ffffff;
    font-weight: 600;
    border: none;
    border-radius: 6px;
    padding: 8px 16px;
    min-height: 20px;
    font-size: 13px;
}
QPushButton:hover {
    background-color: #1d4ed8;
}
QPushButton:pressed {
    background-color: #1e40af;
}
QPushButton:disabled {
    background-color: #cbd5e1;
    color: #94a3b8;
}

QPushButton.btnSecondary {
    background-color: #f1f5f9;
    color: #334155;
    border: 1px solid #cbd5e1;
}
QPushButton.btnSecondary:hover {
    background-color: #e2e8f0;
    color: #0f172a;
}

QPushButton.btnSuccess {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #10b981, stop:1 #059669);
    color: #ffffff;
}
QPushButton.btnSuccess:hover {
    background-color: #047857;
}

QPushButton.btnAccent {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #6366f1, stop:1 #4f46e5);
    color: #ffffff;
}
QPushButton.btnAccent:hover {
    background-color: #4338ca;
}

QCheckBox, QRadioButton {
    spacing: 8px;
    font-weight: 500;
    color: #334155;
}
QCheckBox::indicator, QRadioButton::indicator {
    width: 18px;
    height: 18px;
    border-radius: 4px;
    border: 1.5px solid #94a3b8;
    background: #ffffff;
}
QRadioButton::indicator {
    border-radius: 9px;
}
QCheckBox::indicator:checked, QRadioButton::indicator:checked {
    background-color: #2563eb;
    border-color: #2563eb;
}

QTableWidget {
    background-color: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    gridline-color: #f1f5f9;
    selection-background-color: #eff6ff;
    selection-color: #1e3a8a;
}
QHeaderView::section {
    background-color: #f8fafc;
    color: #475569;
    font-weight: 700;
    font-size: 12px;
    padding: 8px;
    border: none;
    border-bottom: 2px solid #e2e8f0;
}

QTabWidget::pane {
    border: 1px solid #e2e8f0;
    background-color: #ffffff;
    border-radius: 8px;
    top: -1px;
}
QTabBar::tab {
    background-color: #f1f5f9;
    color: #64748b;
    padding: 9px 18px;
    border-top-left-radius: 6px;
    border-top-right-radius: 6px;
    margin-right: 4px;
    font-weight: 600;
}
QTabBar::tab:selected {
    background-color: #ffffff;
    color: #2563eb;
    border-top: 3px solid #2563eb;
    border-left: 1px solid #e2e8f0;
    border-right: 1px solid #e2e8f0;
}

QProgressBar {
    border: 1px solid #e2e8f0;
    border-radius: 4px;
    text-align: center;
    background-color: #f1f5f9;
    height: 14px;
    font-size: 11px;
}
QProgressBar::chunk {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #2563eb, stop:1 #3b82f6);
    border-radius: 3px;
}
"""


# ---------------------------------------------------------------------------
# Main Studio Window Class
# ---------------------------------------------------------------------------

class ProfessionalStudioWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(f"Specialized Reporting v{updater.CURRENT_VERSION} — pcAmerica CRE")
        self.resize(1340, 880)
        self.setMinimumSize(1080, 720)

        if ICON_PATH.exists():
            self.setWindowIcon(QIcon(str(ICON_PATH)))

        self.cfg = load_app_env()
        self.is_admin_unlocked = False
        self.cached_stores: list[dict] = []
        self.latest_bundles: list[ReportBundle] = []
        self.latest_generated_files: list[dict] = []
        self.latest_db_sales_date: Optional[str] = None
        self.latest_db_clock_date: Optional[str] = None
        self.last_preview_html_path: Optional[str] = None
        self.pending_update_info: Optional[updater.UpdateInfo] = None

        self.setStyleSheet(MODERN_STYLESHEET)
        self.setup_ui()
        self.load_settings_into_ui()
        self.apply_lock_state()
        self.auto_connect_on_startup()

        # Check for remote updates quietly if enabled
        if self.cfg.get("AUTO_CHECK_UPDATES", "true").lower() in ("true", "1", "yes"):
            self.trigger_background_update_check(silent=True)

    def closeEvent(self, event):
        if hasattr(self, "fetch_worker") and self.fetch_worker.isRunning():
            self.fetch_worker.terminate()
        if hasattr(self, "report_worker") and self.report_worker.isRunning():
            self.report_worker.terminate()
        if hasattr(self, "email_worker") and self.email_worker.isRunning():
            self.email_worker.terminate()
        if hasattr(self, "update_check_worker") and self.update_check_worker.isRunning():
            self.update_check_worker.terminate()
        event.accept()

    def log(self, message: str, level: str = "INFO"):
        ts = _dt.datetime.now().strftime("%H:%M:%S")
        color = "#2563eb" if level == "INFO" else ("#10b981" if level == "SUCCESS" else ("#ef4444" if level == "ERROR" else "#f59e0b"))
        self.txt_log_console.append(f"<span style='color:#64748b;'>[{ts}]</span> <b style='color:{color};'>[{level}]</b> {message}")

    # -----------------------------------------------------------------------
    # Authentication & Lock State Management
    # -----------------------------------------------------------------------
    def prompt_team_login(self):
        dlg = TeamLoginDialog(self)
        if dlg.exec() == QDialog.DialogCode.Accepted:
            self.is_admin_unlocked = True
            self.apply_lock_state()
            self.log("IT / Support Team authenticated successfully. Full admin access unlocked.", "SUCCESS")
        else:
            self.is_admin_unlocked = False
            self.apply_lock_state()

    def toggle_lock_state(self):
        if self.is_admin_unlocked:
            self.is_admin_unlocked = False
            self.apply_lock_state()
            self.log("Admin privileges locked by user.", "INFO")
        else:
            self.prompt_team_login()

    def apply_lock_state(self):
        unlocked = self.is_admin_unlocked
        
        if unlocked:
            self.btn_lock_status.setText("🔓 Team Mode (Active)")
            self.btn_lock_status.setStyleSheet("background-color: #10b981; color: white; font-weight: bold; padding: 6px 12px;")
            self.lbl_lock_banner.setVisible(False)
        else:
            self.btn_lock_status.setText("🔒 Restricted Mode (Click to Unlock)")
            self.btn_lock_status.setStyleSheet("background-color: #ef4444; color: white; font-weight: bold; padding: 6px 12px;")
            self.lbl_lock_banner.setVisible(True)

        self.combo_server.setEnabled(unlocked)
        self.btn_discover_servers.setEnabled(unlocked)
        self.combo_database.setEnabled(unlocked)
        self.btn_list_dbs.setEnabled(unlocked)
        self.radio_auth_win.setEnabled(unlocked)
        self.radio_auth_sql.setEnabled(unlocked)
        self.txt_user.setEnabled(unlocked and self.radio_auth_sql.isChecked())
        self.txt_pwd.setEnabled(unlocked and self.radio_auth_sql.isChecked())
        self.btn_toggle_pwd.setEnabled(unlocked)
        self.btn_save_top.setEnabled(unlocked)

        self.txt_smtp_host.setEnabled(unlocked)
        self.txt_smtp_port.setEnabled(unlocked)
        self.txt_smtp_user.setEnabled(unlocked)
        self.txt_smtp_pwd.setEnabled(unlocked)
        self.btn_toggle_smtp_pwd.setEnabled(unlocked)
        self.txt_smtp_from.setEnabled(unlocked)
        self.cb_smtp_tls.setEnabled(unlocked)
        self.txt_recipients.setEnabled(unlocked)
        self.txt_sms_recipients.setEnabled(unlocked)

        for cb in self.module_checkboxes.values():
            cb.setEnabled(unlocked)
        self.cb_attach_xlsx.setEnabled(unlocked)
        self.cb_attach_csv.setEnabled(unlocked)
        self.cb_send_sms.setEnabled(unlocked)

        self.time_schedule.setEnabled(unlocked)
        self.cb_schedule_enabled.setEnabled(unlocked)
        self.btn_install_schedule.setEnabled(unlocked)
        self.btn_remove_schedule.setEnabled(unlocked)

        self.txt_github_repo.setEnabled(unlocked)
        self.cb_auto_check_updates.setEnabled(unlocked)

    def open_change_password_dialog(self):
        dlg = TeamLoginDialog(self, is_change_mode=True)
        dlg.exec()

    # -----------------------------------------------------------------------
    # Shell UI Layout & Navigation
    # -----------------------------------------------------------------------
    def setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root_layout = QHBoxLayout(central)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        # 1. Left Navigation Sidebar
        sidebar_frame = QFrame()
        sidebar_frame.setObjectName("sidebarFrame")
        sidebar_frame.setFixedWidth(260)
        side_vbox = QVBoxLayout(sidebar_frame)
        side_vbox.setContentsMargins(14, 18, 14, 16)
        side_vbox.setSpacing(12)

        brand_hbox = QHBoxLayout()
        
        # Branded JD Gurus Emblem Logo
        lbl_logo = QLabel()
        if ICON_PATH.exists():
            pix = QPixmap(str(ICON_PATH)).scaled(38, 38, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            lbl_logo.setPixmap(pix)
        else:
            lbl_logo.setText("📊")
            lbl_logo.setStyleSheet("font-size: 24px;")

        brand_vbox = QVBoxLayout()
        lbl_app_name = QLabel("Specialized")
        lbl_app_name.setStyleSheet("color: #ffffff; font-size: 16px; font-weight: 800; letter-spacing: 0.5px;")
        lbl_app_sub = QLabel("Reporting System")
        lbl_app_sub.setStyleSheet("color: #38bdf8; font-size: 13px; font-weight: 700;")
        brand_vbox.addWidget(lbl_app_name)
        brand_vbox.addWidget(lbl_app_sub)
        
        brand_hbox.addWidget(lbl_logo)
        brand_hbox.addLayout(brand_vbox)
        brand_hbox.addStretch()
        side_vbox.addLayout(brand_hbox)

        sep1 = QFrame()
        sep1.setFrameShape(QFrame.Shape.HLine)
        sep1.setStyleSheet("border-color: #1e293b;")
        side_vbox.addWidget(sep1)

        self.nav_list = QListWidget()
        self.nav_list.setObjectName("navSidebar")
        
        nav_items = [
            ("📊  Live Analytics & KPIs", 0),
            ("🚀  Report Generator & Preview", 1),
            ("🧩  Module & Section Filter", 2),
            ("🔌  SQL Server & Discovery", 3),
            ("📧  Email & SMTP Dispatch", 4),
            ("⚙️  Settings & Scheduling", 5),
        ]
        for label, idx in nav_items:
            item = QListWidgetItem(label)
            item.setSizeHint(QSize(230, 44))
            self.nav_list.addItem(item)

        self.nav_list.currentRowChanged.connect(self.switch_view)
        side_vbox.addWidget(self.nav_list, stretch=1)

        # Side Status Card
        status_card = QFrame()
        status_card.setStyleSheet("background-color: #1e293b; border-radius: 8px; padding: 10px;")
        sc_vbox = QVBoxLayout(status_card)
        sc_vbox.setSpacing(6)
        
        self.lbl_side_db_chip = QLabel("🔴 SQL: Disconnected")
        self.lbl_side_db_chip.setStyleSheet("color: #ef4444; font-weight: bold; font-size: 11px;")
        self.lbl_side_store_chip = QLabel("🏪 Stores: Detecting...")
        self.lbl_side_store_chip.setStyleSheet("color: #94a3b8; font-size: 11px;")
        self.lbl_side_ver_chip = QLabel(f"⚡ App Version: v{updater.CURRENT_VERSION}")
        self.lbl_side_ver_chip.setStyleSheet("color: #38bdf8; font-size: 10px; font-weight: 600;")
        
        sc_vbox.addWidget(self.lbl_side_db_chip)
        sc_vbox.addWidget(self.lbl_side_store_chip)
        sc_vbox.addWidget(self.lbl_side_ver_chip)
        side_vbox.addWidget(status_card)

        self.btn_save_top = QPushButton("💾 Save Config")
        self.btn_save_top.setStyleSheet("background-color: #10b981; color: white; font-weight: bold;")
        self.btn_save_top.clicked.connect(self.save_settings)
        side_vbox.addWidget(self.btn_save_top)

        root_layout.addWidget(sidebar_frame)

        # 2. Main Content Area
        content_widget = QWidget()
        content_widget.setObjectName("contentArea")
        content_layout = QVBoxLayout(content_widget)
        content_layout.setContentsMargins(20, 16, 20, 14)
        content_layout.setSpacing(12)

        top_bar = QFrame()
        top_bar.setStyleSheet("background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 6px 14px;")
        top_layout = QHBoxLayout(top_bar)
        top_layout.setContentsMargins(8, 6, 8, 6)

        self.lbl_page_title = QLabel("Live Analytics & KPIs")
        self.lbl_page_title.setStyleSheet("font-size: 18px; font-weight: 800; color: #0f172a;")
        top_layout.addWidget(self.lbl_page_title)

        top_layout.addStretch()

        self.btn_lock_status = QPushButton("🔒 Restricted Mode (Click to Unlock)")
        self.btn_lock_status.clicked.connect(self.toggle_lock_state)
        top_layout.addWidget(self.btn_lock_status)

        self.lbl_header_db_badge = QLabel("Harshil\\pcamerica / cresqlvick")
        self.lbl_header_db_badge.setStyleSheet("background-color: #f1f5f9; color: #334155; padding: 5px 12px; border-radius: 6px; font-weight: 600; font-size: 12px;")
        top_layout.addWidget(self.lbl_header_db_badge)

        btn_open_reports = QPushButton("📁 Reports Folder")
        btn_open_reports.setProperty("class", "btnSecondary")
        btn_open_reports.clicked.connect(self.open_output_folder)
        top_layout.addWidget(btn_open_reports)

        content_layout.addWidget(top_bar)

        # Update Announcement Banner (Hidden by default)
        self.frame_update_banner = QFrame()
        self.frame_update_banner.setVisible(False)
        self.frame_update_banner.setStyleSheet("background-color: #eff6ff; border: 1.5px solid #3b82f6; border-radius: 8px; padding: 8px 14px;")
        ub_layout = QHBoxLayout(self.frame_update_banner)
        ub_layout.setContentsMargins(4, 2, 4, 2)
        self.lbl_update_banner_text = QLabel("⭐ <b>A new software update is available!</b>")
        self.lbl_update_banner_text.setStyleSheet("color: #1e3a8a; font-size: 12px;")
        ub_layout.addWidget(self.lbl_update_banner_text)
        ub_layout.addStretch()
        self.btn_banner_update_now = QPushButton("⚡ Update Now")
        self.btn_banner_update_now.setStyleSheet("background-color: #2563eb; color: white; font-weight: bold; padding: 4px 12px; font-size: 11px;")
        self.btn_banner_update_now.clicked.connect(self.execute_update_process)
        ub_layout.addWidget(self.btn_banner_update_now)
        content_layout.addWidget(self.frame_update_banner)

        self.lbl_lock_banner = QLabel("🔒 Restricted Merchant Mode: Settings and credentials are protected. Click 'Unlock' above to modify system configuration.")
        self.lbl_lock_banner.setStyleSheet("background-color: #fff7ed; color: #c2410c; border: 1px solid #fed7aa; border-radius: 6px; padding: 6px 12px; font-weight: 600; font-size: 12px;")
        content_layout.addWidget(self.lbl_lock_banner)

        # Stacked Pages
        self.stack = QStackedWidget()
        content_layout.addWidget(self.stack, stretch=1)

        self.view_dashboard = QWidget()
        self.setup_dashboard_view()
        self.stack.addWidget(self.view_dashboard)

        self.view_generator = QWidget()
        self.setup_generator_view()
        self.stack.addWidget(self.view_generator)

        self.view_modules = QWidget()
        self.setup_modules_view()
        self.stack.addWidget(self.view_modules)

        self.view_sql = QWidget()
        self.setup_sql_view()
        self.stack.addWidget(self.view_sql)

        self.view_email = QWidget()
        self.setup_email_view()
        self.stack.addWidget(self.view_email)

        self.view_settings = QWidget()
        self.setup_settings_view()
        self.stack.addWidget(self.view_settings)

        # Bottom Activity Console & Progress Bar
        self.console_frame = QFrame()
        self.console_frame.setStyleSheet("background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px;")
        c_vbox = QVBoxLayout(self.console_frame)
        c_vbox.setContentsMargins(10, 8, 10, 8)
        c_vbox.setSpacing(6)

        c_top = QHBoxLayout()
        lbl_c_title = QLabel("Activity & Event Log")
        lbl_c_title.setStyleSheet("font-weight: 700; font-size: 11px; color: #475569;")
        c_top.addWidget(lbl_c_title)
        c_top.addStretch()

        self.btn_toggle_console = QPushButton("Show Log")
        self.btn_toggle_console.setProperty("class", "btnSecondary")
        self.btn_toggle_console.setFixedHeight(22)
        self.btn_toggle_console.setStyleSheet("font-size: 11px; padding: 2px 8px;")
        self.btn_toggle_console.clicked.connect(self.toggle_console_drawer)
        c_top.addWidget(self.btn_toggle_console)
        c_vbox.addLayout(c_top)

        self.txt_log_console = QTextBrowser()
        self.txt_log_console.setFixedHeight(70)
        self.txt_log_console.setVisible(False)
        self.txt_log_console.setStyleSheet("border: none; background-color: #f8fafc; font-family: 'Consolas', monospace; font-size: 11px; padding: 4px;")
        c_vbox.addWidget(self.txt_log_console)

        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        c_vbox.addWidget(self.progress_bar)

        content_layout.addWidget(self.console_frame)
        root_layout.addWidget(content_widget, stretch=1)

        self.nav_list.setCurrentRow(0)

    def switch_view(self, row: int):
        titles = [
            "Live Analytics & Dashboard",
            "Report Generator & Live Preview",
            "Module & Section Filter",
            "SQL Server Connection & Auto-Discovery",
            "Email & SMTP Dispatch",
            "System Settings & Automated Scheduling",
        ]
        if 0 <= row < len(titles):
            self.lbl_page_title.setText(titles[row])
            self.stack.setCurrentIndex(row)

    def toggle_console_drawer(self):
        is_visible = self.txt_log_console.isVisible()
        self.txt_log_console.setVisible(not is_visible)
        self.btn_toggle_console.setText("Hide Log" if not is_visible else "Show Log")

    # -----------------------------------------------------------------------
    # View 0: Live Analytics & Dashboard
    # -----------------------------------------------------------------------
    def setup_dashboard_view(self):
        layout = QVBoxLayout(self.view_dashboard)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        kpi_frame = QFrame()
        kpi_frame.setProperty("class", "cardFrame")
        kpi_frame.setStyleSheet("background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 12px;")
        k_layout = QHBoxLayout(kpi_frame)
        k_layout.setSpacing(14)

        def make_stat_card(title: str, default_val: str, icon: str, color_hex: str):
            f = QFrame()
            f.setStyleSheet(f"background-color: #f8fafc; border: 1px solid #e2e8f0; border-left: 4px solid {color_hex}; border-radius: 8px; padding: 10px;")
            v = QVBoxLayout(f)
            v.setContentsMargins(6, 4, 6, 4)
            v.setSpacing(2)
            lbl_t = QLabel(f"{icon} {title.upper()}")
            lbl_t.setStyleSheet("font-size: 11px; color: #64748b; font-weight: 700;")
            lbl_v = QLabel(default_val)
            lbl_v.setStyleSheet(f"font-size: 20px; font-weight: 800; color: #0f172a;")
            v.addWidget(lbl_t)
            v.addWidget(lbl_v)
            return f, lbl_v

        f1, self.dash_invoices = make_stat_card("Total Invoices", "0", "🧾", "#2563eb")
        f2, self.dash_gross = make_stat_card("Net Sales Revenue", "$0.00", "💵", "#10b981")
        f3, self.dash_avg = make_stat_card("Average Ticket", "$0.00", "🎯", "#6366f1")
        f4, self.dash_tax = make_stat_card("Sales Tax Collected", "$0.00", "🏛️", "#f59e0b")
        f5, self.dash_cash = make_stat_card("Cash Collected", "$0.00", "💰", "#06b6d4")

        k_layout.addWidget(f1)
        k_layout.addWidget(f2)
        k_layout.addWidget(f3)
        k_layout.addWidget(f4)
        k_layout.addWidget(f5)
        layout.addWidget(kpi_frame)

        split = QSplitter(Qt.Orientation.Horizontal)
        
        grp_items = QGroupBox("Top 10 Best-Selling Items")
        v_it = QVBoxLayout(grp_items)
        self.dash_table_items = QTableWidget(0, 4)
        self.dash_table_items.setHorizontalHeaderLabels(["Rank", "Item Description", "Qty Sold", "Revenue ($)"])
        self.dash_table_items.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.dash_table_items.setAlternatingRowColors(True)
        v_it.addWidget(self.dash_table_items)
        split.addWidget(grp_items)

        grp_dept = QGroupBox("Department Revenue Breakdown")
        v_dp = QVBoxLayout(grp_dept)
        self.dash_table_dept = QTableWidget(0, 4)
        self.dash_table_dept.setHorizontalHeaderLabels(["Dept ID", "Department Name", "Units", "Total Sales ($)"])
        self.dash_table_dept.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.dash_table_dept.setAlternatingRowColors(True)
        v_dp.addWidget(self.dash_table_dept)
        split.addWidget(grp_dept)

        layout.addWidget(split, stretch=1)

    # -----------------------------------------------------------------------
    # View 1: Report Generator & Live Preview
    # -----------------------------------------------------------------------
    def setup_generator_view(self):
        layout = QVBoxLayout(self.view_generator)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(10)

        ctrl_frame = QFrame()
        ctrl_frame.setProperty("class", "cardFrame")
        ctrl_frame.setStyleSheet("background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 10px;")
        ctrl_layout = QHBoxLayout(ctrl_frame)
        ctrl_layout.setContentsMargins(8, 4, 8, 4)
        ctrl_layout.setSpacing(12)

        ctrl_layout.addWidget(QLabel("<b>Store:</b>"))
        self.combo_run_store = QComboBox()
        self.combo_run_store.addItem("All Stores", None)
        ctrl_layout.addWidget(self.combo_run_store)

        ctrl_layout.addWidget(QLabel("<b>Range:</b>"))
        self.combo_date_preset = QComboBox()
        self.combo_date_preset.addItems(["Latest Date in DB", "Yesterday", "Today", "Last 7 Days", "Custom Range"])
        self.combo_date_preset.currentIndexChanged.connect(self.on_date_preset_changed)
        ctrl_layout.addWidget(self.combo_date_preset)

        self.dt_start = QDateEdit()
        self.dt_start.setCalendarPopup(True)
        self.dt_start.setDate(QDate.currentDate().addDays(-1))
        ctrl_layout.addWidget(self.dt_start)

        ctrl_layout.addWidget(QLabel("to"))

        self.dt_end = QDateEdit()
        self.dt_end.setCalendarPopup(True)
        self.dt_end.setDate(QDate.currentDate().addDays(-1))
        ctrl_layout.addWidget(self.dt_end)

        ctrl_layout.addStretch()

        self.btn_generate_preview = QPushButton("🚀 Generate Report")
        self.btn_generate_preview.setProperty("class", "btnSuccess")
        self.btn_generate_preview.clicked.connect(self.generate_and_preview_report)
        ctrl_layout.addWidget(self.btn_generate_preview)

        self.btn_send_email_now = QPushButton("✉️ Dispatch Email")
        self.btn_send_email_now.setProperty("class", "btnAccent")
        self.btn_send_email_now.clicked.connect(self.send_email_now)
        ctrl_layout.addWidget(self.btn_send_email_now)

        layout.addWidget(ctrl_frame)

        self.preview_tabs = QTabWidget()

        # Tab 1: Instant Native HTML Document Browser
        tab_html = QWidget()
        th_vbox = QVBoxLayout(tab_html)
        th_vbox.setContentsMargins(6, 6, 6, 6)

        th_toolbar = QHBoxLayout()
        lbl_p_info = QLabel("<b>Instant Email Layout Preview</b> (Formatting & Tables)")
        lbl_p_info.setStyleSheet("color: #475569; font-size: 12px;")
        th_toolbar.addWidget(lbl_p_info)
        th_toolbar.addStretch()

        self.btn_open_in_browser = QPushButton("🌐 Open in Web Browser (Edge / Chrome)")
        self.btn_open_in_browser.setProperty("class", "btnSecondary")
        self.btn_open_in_browser.clicked.connect(self.open_current_report_in_browser)
        th_toolbar.addWidget(self.btn_open_in_browser)
        th_vbox.addLayout(th_toolbar)

        self.preview_browser = QTextBrowser()
        self.preview_browser.setStyleSheet("border: 1px solid #e2e8f0; border-radius: 6px; background-color: #ffffff; padding: 10px;")
        self.preview_browser.setOpenExternalLinks(True)
        th_vbox.addWidget(self.preview_browser)
        self.preview_tabs.addTab(tab_html, "📄 Rendered HTML Email Layout")

        # Tab 2: Itemized Transactions Table
        tab_tx = QWidget()
        tx_vbox = QVBoxLayout(tab_tx)
        tx_vbox.setContentsMargins(6, 6, 6, 6)
        self.table_tx = QTableWidget(0, 8)
        self.table_tx.setHorizontalHeaderLabels(["Invoice #", "Timestamp", "Cashier", "Item Name", "Qty", "Price", "Ext Price", "Tax"])
        self.table_tx.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        self.table_tx.setAlternatingRowColors(True)
        tx_vbox.addWidget(self.table_tx)
        self.preview_tabs.addTab(tab_tx, "🧾 Itemized Transactions")

        # Tab 3: Employee Time Clock
        tab_emp = QWidget()
        emp_vbox = QVBoxLayout(tab_emp)
        emp_vbox.setContentsMargins(6, 6, 6, 6)
        self.table_emp = QTableWidget(0, 6)
        self.table_emp.setHorizontalHeaderLabels(["Emp ID", "Employee Name", "Clock In", "Clock Out", "Total Hours", "Hourly Wage"])
        self.table_emp.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.table_emp.setAlternatingRowColors(True)
        emp_vbox.addWidget(self.table_emp)
        self.preview_tabs.addTab(tab_emp, "👥 Employee TimeClock")

        # Tab 4: Audit & Loss Prevention
        tab_audit = QWidget()
        aud_vbox = QVBoxLayout(tab_audit)
        aud_vbox.setContentsMargins(6, 6, 6, 6)
        self.table_audit = QTableWidget(0, 6)
        self.table_audit.setHorizontalHeaderLabels(["Event Type", "Invoice #", "Cashier", "Item / Details", "Old / Overridden", "Amount ($)"])
        self.table_audit.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        self.table_audit.setAlternatingRowColors(True)
        aud_vbox.addWidget(self.table_audit)
        self.preview_tabs.addTab(tab_audit, "🛡️ Loss Prevention & Audit")

        layout.addWidget(self.preview_tabs, stretch=1)

    def open_current_report_in_browser(self):
        if self.last_preview_html_path and Path(self.last_preview_html_path).exists():
            webbrowser.open(Path(self.last_preview_html_path).as_uri())
        else:
            QMessageBox.information(self, "Notice", "Please generate a report first.")

    def on_date_preset_changed(self, index: int):
        preset = self.combo_date_preset.currentText()
        today = QDate.currentDate()
        if preset == "Yesterday":
            y = today.addDays(-1)
            self.dt_start.setDate(y)
            self.dt_end.setDate(y)
        elif preset == "Today":
            self.dt_start.setDate(today)
            self.dt_end.setDate(today)
        elif preset == "Last 7 Days":
            self.dt_start.setDate(today.addDays(-7))
            self.dt_end.setDate(today)
        elif preset == "Latest Date in DB":
            if self.latest_db_sales_date:
                qd = QDate.fromString(self.latest_db_sales_date, "yyyy-MM-dd")
                if qd.isValid():
                    self.dt_start.setDate(qd)
                    self.dt_end.setDate(qd)

    # -----------------------------------------------------------------------
    # View 2: Modular Filter & Sections
    # -----------------------------------------------------------------------
    def setup_modules_view(self):
        layout = QVBoxLayout(self.view_modules)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        top_hbox = QHBoxLayout()
        desc = QLabel("Customize exactly which modules appear in the generated HTML email, Excel workbook, and CSVs:")
        desc.setStyleSheet("font-size: 13px; color: #475569; font-weight: 500;")
        top_hbox.addWidget(desc)
        top_hbox.addStretch()

        btn_all = QPushButton("Select All")
        btn_all.setProperty("class", "btnSecondary")
        btn_all.clicked.connect(self.select_all_modules)
        top_hbox.addWidget(btn_all)

        btn_none = QPushButton("Clear All")
        btn_none.setProperty("class", "btnSecondary")
        btn_none.clicked.connect(self.clear_all_modules)
        top_hbox.addWidget(btn_none)

        layout.addLayout(top_hbox)

        presets_hbox = QHBoxLayout()
        presets_hbox.addWidget(QLabel("<b>Presets:</b>"))

        btn_p_sales = QPushButton("📊 Sales Only")
        btn_p_sales.setProperty("class", "btnSecondary")
        btn_p_sales.clicked.connect(lambda: self.apply_module_preset(["kpis", "departments", "fixed_tax", "top_items", "hourly", "payments"]))
        presets_hbox.addWidget(btn_p_sales)

        btn_p_staff = QPushButton("👥 Staff Only")
        btn_p_staff.setProperty("class", "btnSecondary")
        btn_p_staff.clicked.connect(lambda: self.apply_module_preset(["employees"]))
        presets_hbox.addWidget(btn_p_staff)

        btn_p_audit = QPushButton("🛡️ Audit Only")
        btn_p_audit.setProperty("class", "btnSecondary")
        btn_p_audit.clicked.connect(lambda: self.apply_module_preset(["voids", "price_changes", "deletes"]))
        presets_hbox.addWidget(btn_p_audit)

        btn_p_full = QPushButton("🌟 Complete Standard Report")
        btn_p_full.setProperty("class", "btnSecondary")
        btn_p_full.clicked.connect(lambda: self.apply_module_preset(list(DEFAULT_SECTIONS)))
        presets_hbox.addWidget(btn_p_full)

        presets_hbox.addStretch()
        layout.addLayout(presets_hbox)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("border: 1px solid #e2e8f0; border-radius: 10px; background-color: #ffffff;")
        scroll_content = QWidget()
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setContentsMargins(14, 14, 14, 14)
        scroll_layout.setSpacing(12)

        self.module_checkboxes: dict[str, QCheckBox] = {}

        categories = {
            "📊 Sales Performance & Analytics": [
                ("kpis", "Key Metrics / KPIs", "Invoice count, Gross/Net Sales, Average Ticket, Taxed/Exempt, Sales Tax, Fixed Tax, Discounts, Cash."),
                ("departments", "Sales by Department", "Departmental breakdown with item quantities, revenue, fixed taxes, and percentage of sales."),
                ("fixed_tax", "Sales by Fixed Tax Bucket", "Sales grouped by Fixed Tax amount ($0.15, $0.30, etc.) with totals."),
                ("top_items", "Top 20 Best Sellers", "Highest revenue generating items sold during the period."),
                ("hourly", "Hourly Sales Curve", "Hourly sales distribution and invoice count throughout the trading day."),
                ("payments", "Payment Method Breakdown", "Cash, Credit Card, Debit Card, Check, Gift Card, On Account, Mobile Pay."),
            ],
            "👥 Staff & Store Operations": [
                ("employees", "Employee TimeClock & Shifts", "Staff shifts, clock-in/out timestamps, total hours worked, break times, and wages."),
            ],
            "🛡️ Loss Prevention & Security Audit": [
                ("voids", "Invoice & Line Item Voids", "Voided transactions with cashier ID, timestamp, and voided amount."),
                ("price_changes", "Price Overrides & Changes", "Manual item price overrides with cashier ID, original price, new price, and difference."),
                ("deletes", "Line Item Deletions", "Line items deleted before completing the invoice with cashier ID and details."),
            ],
            "📄 Export Attachments & Detail Logs": [
                ("transactions", "Itemized Transactions Detail", "Full itemized line-by-line transaction journal."),
            ]
        }

        for cat_title, items in categories.items():
            grp = QGroupBox(cat_title)
            g_vbox = QVBoxLayout(grp)
            g_vbox.setSpacing(8)
            for sec_key, title, d_text in items:
                row_hbox = QHBoxLayout()
                cb = QCheckBox(f"{title}")
                cb.setChecked(True)
                self.module_checkboxes[sec_key] = cb
                row_hbox.addWidget(cb)
                
                lbl_d = QLabel(f"— {d_text}")
                lbl_d.setStyleSheet("color: #64748b; font-size: 12px;")
                row_hbox.addWidget(lbl_d)
                row_hbox.addStretch()
                g_vbox.addLayout(row_hbox)
            scroll_layout.addWidget(grp)

        grp_attach = QGroupBox("📎 Attachment & Notification Delivery Options")
        att_vbox = QVBoxLayout(grp_attach)
        self.cb_attach_xlsx = QCheckBox("Include Styled Excel (.xlsx) Multi-Sheet Workbook Attachment")
        self.cb_attach_xlsx.setChecked(True)
        att_vbox.addWidget(self.cb_attach_xlsx)

        self.cb_attach_csv = QCheckBox("Include Raw CSV Detail Files (Transactions, Employees, Audit Events)")
        self.cb_attach_csv.setChecked(True)
        att_vbox.addWidget(self.cb_attach_csv)

        self.cb_send_sms = QCheckBox("Send Mobile Text Summary via Email-to-SMS Gateways")
        self.cb_send_sms.setChecked(False)
        att_vbox.addWidget(self.cb_send_sms)

        scroll_layout.addWidget(grp_attach)

        scroll.setWidget(scroll_content)
        layout.addWidget(scroll, stretch=1)

    def select_all_modules(self):
        for cb in self.module_checkboxes.values():
            cb.setChecked(True)

    def clear_all_modules(self):
        for cb in self.module_checkboxes.values():
            cb.setChecked(False)

    def apply_module_preset(self, enabled_keys: list[str]):
        target_set = set(enabled_keys)
        for key, cb in self.module_checkboxes.items():
            cb.setChecked(key in target_set)

    def get_selected_sections(self) -> set[str]:
        return {k for k, cb in self.module_checkboxes.items() if cb.isChecked()}

    # -----------------------------------------------------------------------
    # View 3: SQL Server Connection & Discovery
    # -----------------------------------------------------------------------
    def setup_sql_view(self):
        layout = QVBoxLayout(self.view_sql)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(14)

        grp_conn = QGroupBox("SQL Server Database Connection")
        g_layout = QGridLayout(grp_conn)
        g_layout.setSpacing(12)
        g_layout.setContentsMargins(16, 18, 16, 16)

        g_layout.addWidget(QLabel("SQL Server Instance:"), 0, 0)
        self.combo_server = QComboBox()
        self.combo_server.setEditable(True)
        self.combo_server.addItems([r"Harshil\pcamerica", r"localhost\pcamerica", r"localhost\SQLEXPRESS", "localhost"])
        g_layout.addWidget(self.combo_server, 0, 1)

        self.btn_discover_servers = QPushButton("🔍 Discover Instances")
        self.btn_discover_servers.setProperty("class", "btnSecondary")
        self.btn_discover_servers.clicked.connect(self.discover_instances)
        g_layout.addWidget(self.btn_discover_servers, 0, 2)

        g_layout.addWidget(QLabel("Database Name:"), 1, 0)
        self.combo_database = QComboBox()
        self.combo_database.setEditable(True)
        self.combo_database.addItems(["cresqlvick", "cresql", "pcamerica"])
        g_layout.addWidget(self.combo_database, 1, 1)

        self.btn_list_dbs = QPushButton("📋 Fetch Databases")
        self.btn_list_dbs.setProperty("class", "btnSecondary")
        self.btn_list_dbs.clicked.connect(self.fetch_databases_list)
        g_layout.addWidget(self.btn_list_dbs, 1, 2)

        g_layout.addWidget(QLabel("Authentication Mode:"), 2, 0)
        auth_hbox = QHBoxLayout()
        self.radio_auth_win = QRadioButton("🪟 Windows Authentication (Trusted Connection)")
        self.radio_auth_sql = QRadioButton("🔑 SQL Server Authentication (Username & Password)")
        self.radio_auth_sql.setChecked(True)
        self.radio_auth_win.toggled.connect(self.toggle_auth_fields)
        auth_hbox.addWidget(self.radio_auth_win)
        auth_hbox.addWidget(self.radio_auth_sql)
        auth_hbox.addStretch()
        g_layout.addLayout(auth_hbox, 2, 1, 1, 2)

        self.lbl_user = QLabel("SQL Username:")
        self.txt_user = QLineEdit("sa")
        g_layout.addWidget(self.lbl_user, 3, 0)
        g_layout.addWidget(self.txt_user, 3, 1)

        self.lbl_pwd = QLabel("SQL Password:")
        pwd_hbox = QHBoxLayout()
        self.txt_pwd = QLineEdit("pcAmer1ca")
        self.txt_pwd.setEchoMode(QLineEdit.EchoMode.Password)
        self.btn_toggle_pwd = QPushButton("👁️")
        self.btn_toggle_pwd.setProperty("class", "btnSecondary")
        self.btn_toggle_pwd.setFixedWidth(36)
        self.btn_toggle_pwd.clicked.connect(lambda: self.toggle_echo(self.txt_pwd, self.btn_toggle_pwd))
        pwd_hbox.addWidget(self.txt_pwd)
        pwd_hbox.addWidget(self.btn_toggle_pwd)

        g_layout.addWidget(self.lbl_pwd, 4, 0)
        g_layout.addLayout(pwd_hbox, 4, 1)

        btn_box = QHBoxLayout()
        self.btn_test_db = QPushButton("⚡ Test Connection")
        self.btn_test_db.setProperty("class", "btnAccent")
        self.btn_test_db.clicked.connect(self.test_db_connection)
        btn_box.addWidget(self.btn_test_db)

        self.btn_fetch_server_details = QPushButton("🔄 Auto-Fetch Server Details")
        self.btn_fetch_server_details.clicked.connect(self.auto_fetch_server_details)
        btn_box.addWidget(self.btn_fetch_server_details)

        btn_box.addStretch()
        g_layout.addLayout(btn_box, 5, 1, 1, 2)

        layout.addWidget(grp_conn)

        grp_details = QGroupBox("Discovered Merchants & Stores in dbo.Setup")
        det_layout = QVBoxLayout(grp_details)
        det_layout.setContentsMargins(14, 16, 14, 14)

        self.table_stores = QTableWidget(0, 5)
        self.table_stores.setHorizontalHeaderLabels(["Store ID", "Store Name / Merchant", "Address", "Phone", "Email"])
        self.table_stores.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.table_stores.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self.table_stores.setAlternatingRowColors(True)
        det_layout.addWidget(self.table_stores)

        meta_hbox = QHBoxLayout()
        self.lbl_latest_sales = QLabel("Latest Sales Date: Unknown")
        self.lbl_latest_sales.setStyleSheet("font-weight: bold; color: #2563eb;")
        self.lbl_latest_clock = QLabel("Latest TimeClock Date: Unknown")
        self.lbl_latest_clock.setStyleSheet("font-weight: bold; color: #64748b;")
        meta_hbox.addWidget(self.lbl_latest_sales)
        meta_hbox.addWidget(self.lbl_latest_clock)
        meta_hbox.addStretch()
        det_layout.addLayout(meta_hbox)

        layout.addWidget(grp_details, stretch=1)

    def toggle_auth_fields(self):
        is_sql = self.radio_auth_sql.isChecked()
        self.lbl_user.setEnabled(is_sql and self.is_admin_unlocked)
        self.txt_user.setEnabled(is_sql and self.is_admin_unlocked)
        self.lbl_pwd.setEnabled(is_sql and self.is_admin_unlocked)
        self.txt_pwd.setEnabled(is_sql and self.is_admin_unlocked)
        self.btn_toggle_pwd.setEnabled(is_sql and self.is_admin_unlocked)

    def toggle_echo(self, line_edit: QLineEdit, btn: QPushButton):
        if line_edit.echoMode() == QLineEdit.EchoMode.Password:
            line_edit.setEchoMode(QLineEdit.EchoMode.Normal)
            btn.setText("🔒")
        else:
            line_edit.setEchoMode(QLineEdit.EchoMode.Password)
            btn.setText("👁️")

    # -----------------------------------------------------------------------
    # View 4: Email & SMTP Dispatch
    # -----------------------------------------------------------------------
    def setup_email_view(self):
        layout = QVBoxLayout(self.view_email)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(14)

        grp_smtp = QGroupBox("SMTP Outgoing Mail Server Configuration")
        s_layout = QGridLayout(grp_smtp)
        s_layout.setSpacing(12)
        s_layout.setContentsMargins(16, 18, 16, 16)

        s_layout.addWidget(QLabel("SMTP Host:"), 0, 0)
        self.txt_smtp_host = QLineEdit("smtp.gmail.com")
        s_layout.addWidget(self.txt_smtp_host, 0, 1)

        s_layout.addWidget(QLabel("SMTP Port:"), 0, 2)
        self.txt_smtp_port = QLineEdit("587")
        self.txt_smtp_port.setFixedWidth(80)
        s_layout.addWidget(self.txt_smtp_port, 0, 3)

        s_layout.addWidget(QLabel("SMTP Username / Email:"), 1, 0)
        self.txt_smtp_user = QLineEdit("harshilp.job10@gmail.com")
        s_layout.addWidget(self.txt_smtp_user, 1, 1, 1, 3)

        s_layout.addWidget(QLabel("Google App Password:"), 2, 0)
        pwd_box = QHBoxLayout()
        self.txt_smtp_pwd = QLineEdit("ultb bstt ebjf adrr")
        self.txt_smtp_pwd.setEchoMode(QLineEdit.EchoMode.Password)
        self.btn_toggle_smtp_pwd = QPushButton("👁️")
        self.btn_toggle_smtp_pwd.setProperty("class", "btnSecondary")
        self.btn_toggle_smtp_pwd.setFixedWidth(36)
        self.btn_toggle_smtp_pwd.clicked.connect(lambda: self.toggle_echo(self.txt_smtp_pwd, self.btn_toggle_smtp_pwd))
        pwd_box.addWidget(self.txt_smtp_pwd)
        pwd_box.addWidget(self.btn_toggle_smtp_pwd)
        s_layout.addLayout(pwd_box, 2, 1, 1, 3)

        s_layout.addWidget(QLabel("From Header:"), 3, 0)
        self.txt_smtp_from = QLineEdit("Daily Reports <harshilp.job10@gmail.com>")
        s_layout.addWidget(self.txt_smtp_from, 3, 1, 1, 3)

        self.cb_smtp_tls = QCheckBox("Enable STARTTLS (Required for Gmail port 587)")
        self.cb_smtp_tls.setChecked(True)
        s_layout.addWidget(self.cb_smtp_tls, 4, 1, 1, 3)

        layout.addWidget(grp_smtp)

        grp_recip = QGroupBox("Report Delivery & Recipients")
        r_layout = QGridLayout(grp_recip)
        r_layout.setSpacing(12)
        r_layout.setContentsMargins(16, 18, 16, 16)

        r_layout.addWidget(QLabel("Report Recipients (comma-separated):"), 0, 0)
        self.txt_recipients = QLineEdit("harshil@jdgurus.com")
        r_layout.addWidget(self.txt_recipients, 0, 1)

        r_layout.addWidget(QLabel("SMS Gateway Recipients (optional):"), 1, 0)
        self.txt_sms_recipients = QLineEdit()
        r_layout.addWidget(self.txt_sms_recipients, 1, 1)

        self.cb_dry_run = QCheckBox("🛡️ Dry-Run Mode (Generate and save files locally, do NOT transmit real emails)")
        r_layout.addWidget(self.cb_dry_run, 2, 1)

        act_box = QHBoxLayout()
        self.btn_test_email = QPushButton("✉️ Send Test Email")
        self.btn_test_email.setProperty("class", "btnAccent")
        self.btn_test_email.clicked.connect(self.send_test_email)
        act_box.addWidget(self.btn_test_email)
        act_box.addStretch()
        r_layout.addLayout(act_box, 3, 1)

        layout.addWidget(grp_recip)
        layout.addStretch()

    # -----------------------------------------------------------------------
    # View 5: Settings & Automated Scheduling
    # -----------------------------------------------------------------------
    def setup_settings_view(self):
        layout = QVBoxLayout(self.view_settings)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(14)

        # 1. GitHub Remote Updates & Auto-Updater Box
        grp_updates = QGroupBox("🔄 GitHub Remote Updates & Auto-Updater")
        u_layout = QGridLayout(grp_updates)
        u_layout.setSpacing(12)
        u_layout.setContentsMargins(16, 18, 16, 16)

        u_layout.addWidget(QLabel("Installed Version:"), 0, 0)
        lbl_v_chip = QLabel(f"<b>Specialized Reporting v{updater.CURRENT_VERSION}</b>")
        lbl_v_chip.setStyleSheet("background-color: #eff6ff; color: #2563eb; padding: 4px 10px; border-radius: 6px; font-weight: 700;")
        u_layout.addWidget(lbl_v_chip, 0, 1)

        self.btn_check_updates_now = QPushButton("🔍 Check for Updates Now")
        self.btn_check_updates_now.setProperty("class", "btnSecondary")
        self.btn_check_updates_now.clicked.connect(lambda: self.trigger_background_update_check(silent=False))
        u_layout.addWidget(self.btn_check_updates_now, 0, 2)

        u_layout.addWidget(QLabel("GitHub Repository:"), 1, 0)
        self.txt_github_repo = QLineEdit("0784harshil/specializedreporting")
        u_layout.addWidget(self.txt_github_repo, 1, 1)

        self.cb_auto_check_updates = QCheckBox("Automatically check for updates on startup")
        self.cb_auto_check_updates.setChecked(True)
        u_layout.addWidget(self.cb_auto_check_updates, 1, 2)

        lbl_up_info = QLabel("Updates automatically replace the executable and modules without overwriting your database connection or settings.")
        lbl_up_info.setStyleSheet("color: #64748b; font-size: 12px;")
        u_layout.addWidget(lbl_up_info, 2, 0, 1, 3)

        layout.addWidget(grp_updates)

        # 2. Automated Schedule Box
        grp_sched = QGroupBox("⏰ Automated Daily Report Scheduling")
        sc_layout = QGridLayout(grp_sched)
        sc_layout.setSpacing(12)
        sc_layout.setContentsMargins(16, 18, 16, 16)

        sc_layout.addWidget(QLabel("Daily Dispatch Time:"), 0, 0)
        self.time_schedule = QTimeEdit()
        self.time_schedule.setDisplayFormat("hh:mm AP")
        self.time_schedule.setTime(QTime(7, 0))
        sc_layout.addWidget(self.time_schedule, 0, 1)

        self.cb_schedule_enabled = QCheckBox("Enable Windows Automated Task Dispatch")
        self.cb_schedule_enabled.setChecked(True)
        sc_layout.addWidget(self.cb_schedule_enabled, 0, 2)

        lbl_sc_info = QLabel("Configure the exact daily time when automated sales reports are processed and emailed:")
        lbl_sc_info.setStyleSheet("color: #64748b; font-size: 12px;")
        sc_layout.addWidget(lbl_sc_info, 1, 0, 1, 3)

        btn_box_sc = QHBoxLayout()
        self.btn_install_schedule = QPushButton("⚡ Register / Update Windows Task Schedule")
        self.btn_install_schedule.setProperty("class", "btnSuccess")
        self.btn_install_schedule.clicked.connect(self.register_windows_task)
        btn_box_sc.addWidget(self.btn_install_schedule)

        self.btn_remove_schedule = QPushButton("🗑️ Remove Task Schedule")
        self.btn_remove_schedule.setProperty("class", "btnSecondary")
        self.btn_remove_schedule.clicked.connect(self.remove_windows_task)
        btn_box_sc.addWidget(self.btn_remove_schedule)
        btn_box_sc.addStretch()

        sc_layout.addLayout(btn_box_sc, 2, 0, 1, 3)
        layout.addWidget(grp_sched)

        # 3. Security Box
        grp_auth = QGroupBox("🔐 Team Master Password & Security Gate")
        a_layout = QVBoxLayout(grp_auth)
        a_layout.setSpacing(10)
        a_layout.setContentsMargins(16, 18, 16, 16)

        lbl_auth_desc = QLabel(
            "Protect SQL credentials, SMTP passwords, and report recipient settings with cryptographic salted hashing. "
            "Only authorized IT/Support team members can modify connection parameters."
        )
        lbl_auth_desc.setWordWrap(True)
        a_layout.addWidget(lbl_auth_desc)

        btn_ch_pwd = QPushButton("🔑 Change Team Master Password")
        btn_ch_pwd.setProperty("class", "btnSecondary")
        btn_ch_pwd.clicked.connect(self.open_change_password_dialog)
        a_layout.addWidget(btn_ch_pwd)

        layout.addWidget(grp_auth)

        # 4. Storage Box
        grp_dirs = QGroupBox("Directories & Storage")
        d_layout = QGridLayout(grp_dirs)
        d_layout.setSpacing(12)
        d_layout.setContentsMargins(16, 18, 16, 16)

        d_layout.addWidget(QLabel("Reports Output Directory:"), 0, 0)
        self.txt_output_dir = QLineEdit(str(OUTPUT_ROOT))
        d_layout.addWidget(self.txt_output_dir, 0, 1)

        btn_browse = QPushButton("📁 Browse...")
        btn_browse.setProperty("class", "btnSecondary")
        btn_browse.clicked.connect(self.browse_output_dir)
        d_layout.addWidget(btn_browse, 0, 2)

        layout.addWidget(grp_dirs)
        layout.addStretch()

    # -----------------------------------------------------------------------
    # Auto-Updater Workflow
    # -----------------------------------------------------------------------
    def trigger_background_update_check(self, silent: bool = True):
        repo = self.cfg.get("GITHUB_REPO", "0784harshil/specializedreporting").strip()
        self.update_check_silent = silent

        if not silent:
            self.log(f"Checking for software updates on GitHub repository ({repo})...")
            self.progress_bar.setVisible(True)
            self.progress_bar.setRange(0, 0)

        self.update_check_worker = UpdateCheckWorker(repo)
        self.update_check_worker.check_finished.connect(self.on_update_check_result)
        self.update_check_worker.error.connect(self.on_update_check_error)
        self.update_check_worker.start()

    def on_update_check_result(self, info: updater.UpdateInfo):
        self.progress_bar.setVisible(False)
        self.pending_update_info = info

        if info.available:
            self.lbl_update_banner_text.setText(f"⭐ <b>New Update Available: v{info.latest_version}</b> — {info.changelog}")
            self.frame_update_banner.setVisible(True)
            self.log(f"Update available: v{info.latest_version} (Current: v{updater.CURRENT_VERSION})", "WARN")

            if info.is_forced:
                # Mandatory Force Update Workflow
                box = QMessageBox(self)
                box.setWindowTitle("🚨 Mandatory Software Update Required")
                box.setIcon(QMessageBox.Icon.Warning)
                box.setText(f"<h3>Specialized Reporting v{info.latest_version} is required</h3>"
                            f"<p>A critical update has been published by JD Gurus that must be installed before continuing.</p>"
                            f"<p><b>Changelog:</b> {info.changelog}</p>")
                btn_up = box.addButton("⚡ Update & Restart Now", QMessageBox.ButtonRole.AcceptRole)
                box.exec()
                self.execute_update_process()
            elif not getattr(self, "update_check_silent", True):
                res = QMessageBox.question(
                    self,
                    "Update Available",
                    f"A new version (v{info.latest_version}) is available!\n\n"
                    f"Current Version: v{updater.CURRENT_VERSION}\n"
                    f"Release Date: {info.release_date or 'Recent'}\n\n"
                    f"Changelog:\n{info.changelog}\n\n"
                    f"Would you like to download and install this update now?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                )
                if res == QMessageBox.StandardButton.Yes:
                    self.execute_update_process()
        else:
            self.frame_update_banner.setVisible(False)
            if not getattr(self, "update_check_silent", True):
                QMessageBox.information(self, "Up to Date", f"✅ Specialized Reporting is up to date (v{updater.CURRENT_VERSION}).")

    def on_update_check_error(self, err: str):
        self.progress_bar.setVisible(False)
        if not getattr(self, "update_check_silent", True):
            self.log(f"Update check notice: {err}", "WARN")
            QMessageBox.warning(self, "Update Check Error", f"Could not check for updates:\n{err}")

    def execute_update_process(self):
        if not self.pending_update_info or not self.pending_update_info.download_url:
            QMessageBox.warning(self, "Update Error", "No valid update download URL found.")
            return

        info = self.pending_update_info
        target_path = BASE_DIR / "Specialized_Reporting.exe.new"

        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.log(f"Downloading v{info.latest_version} from {info.download_url}...", "INFO")

        self.update_download_worker = UpdateDownloadWorker(info.download_url, target_path)
        self.update_download_worker.progress.connect(self.on_download_progress)
        self.update_download_worker.complete.connect(self.on_download_complete)
        self.update_download_worker.error.connect(self.on_download_error)
        self.update_download_worker.start()

    def on_download_progress(self, downloaded: int, total: int):
        if total > 0:
            pct = int((downloaded / total) * 100)
            self.progress_bar.setValue(pct)
            self.progress_bar.setFormat(f"Downloading update... {pct}% ({downloaded // 1048576}MB / {total // 1048576}MB)")
        else:
            self.progress_bar.setRange(0, 0)

    def on_download_complete(self, target_path_str: str):
        self.progress_bar.setVisible(False)
        self.log("Download complete! Applying update and restarting...", "SUCCESS")
        
        QMessageBox.information(
            self,
            "Restarting for Update",
            "✅ Software update downloaded successfully!\n\n"
            "The application will now restart automatically to apply the new version.\n"
            "Your database connection and credentials will remain completely preserved.",
        )
        try:
            updater.apply_update_and_restart(BASE_DIR, "Specialized_Reporting.exe")
        except Exception as e:
            QMessageBox.critical(self, "Update Error", f"Failed applying update:\n{e}")

    def on_download_error(self, err: str):
        self.progress_bar.setVisible(False)
        self.log(f"Download failed: {err}", "ERROR")
        QMessageBox.critical(self, "Download Error", f"❌ Failed downloading software update:\n\n{err}")

    def register_windows_task(self):
        time_str = self.time_schedule.time().toString("HH:mm")
        exe_path = Path(sys.executable).resolve() if getattr(sys, "frozen", False) else (BASE_DIR / "Specialized_Reporting.exe")

        # Windows Task Scheduler calls Specialized_Reporting.exe with --scheduled flag
        cmd = [
            "schtasks", "/create",
            "/tn", "pcAmerica_Daily_Sales_Report",
            "/tr", f'"{exe_path}" --scheduled',
            "/sc", "daily",
            "/st", time_str,
            "/f",
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                self.log(f"Windows Task Scheduler configured for {self.time_schedule.time().toString('hh:mm AP')} using Specialized_Reporting.exe.", "SUCCESS")
                QMessageBox.information(self, "Scheduler Registered", f"✅ Successfully registered Windows Task Scheduler to run daily at {self.time_schedule.time().toString('hh:mm AP')} via Specialized_Reporting.exe!")
            else:
                self.log(f"Scheduler registration notice: {res.stderr.strip()}", "WARN")
                QMessageBox.warning(self, "Scheduler Notice", f"Result:\n{res.stdout or res.stderr}")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed executing schtasks:\n{e}")

    def remove_windows_task(self):
        cmd = ["schtasks", "/delete", "/tn", "pcAmerica_Daily_Sales_Report", "/f"]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True)
            self.log("Removed pcAmerica scheduled task.", "INFO")
            QMessageBox.information(self, "Task Removed", "Windows scheduled task removed.")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed removing task:\n{e}")

    def browse_output_dir(self):
        d = QFileDialog.getExistingDirectory(self, "Select Output Directory", str(OUTPUT_ROOT))
        if d:
            self.txt_output_dir.setText(d)

    # -----------------------------------------------------------------------
    # Settings Load / Collect / Save
    # -----------------------------------------------------------------------
    def load_settings_into_ui(self):
        cfg = self.cfg

        srv = cfg.get("SQL_SERVER", "")
        idx = self.combo_server.findText(srv)
        if idx >= 0:
            self.combo_server.setCurrentIndex(idx)
        else:
            self.combo_server.setEditText(srv)

        db = cfg.get("SQL_DATABASE", "cresqlvick")
        idx_db = self.combo_database.findText(db)
        if idx_db >= 0:
            self.combo_database.setCurrentIndex(idx_db)
        else:
            self.combo_database.setEditText(db)

        auth = cfg.get("SQL_AUTH", "sql").lower()
        if auth in ("sql", "sql server", "sql server authentication"):
            self.radio_auth_sql.setChecked(True)
        else:
            self.radio_auth_win.setChecked(True)
        self.toggle_auth_fields()

        self.txt_user.setText(cfg.get("SQL_USER", "sa"))
        self.txt_pwd.setText(cfg.get("SQL_PASSWORD", "pcAmer1ca"))

        self.txt_smtp_host.setText(cfg.get("SMTP_HOST", "smtp.gmail.com"))
        self.txt_smtp_port.setText(cfg.get("SMTP_PORT", "587"))
        self.txt_smtp_user.setText(cfg.get("SMTP_USER", "harshilp.job10@gmail.com"))
        self.txt_smtp_pwd.setText(cfg.get("SMTP_PASSWORD", "ultb bstt ebjf adrr"))
        self.txt_smtp_from.setText(cfg.get("SMTP_FROM", "Daily Reports <harshilp.job10@gmail.com>"))
        self.cb_smtp_tls.setChecked(cfg.get("SMTP_USE_TLS", "true").lower() in ("true", "1", "yes"))

        self.txt_recipients.setText(cfg.get("REPORT_RECIPIENT", "harshil@jdgurus.com"))
        self.txt_sms_recipients.setText(cfg.get("SMS_RECIPIENTS", ""))
        self.cb_dry_run.setChecked(cfg.get("DRY_RUN", "false").lower() in ("true", "1", "yes"))

        raw_sections = cfg.get("REPORT_SECTIONS", "")
        active_set = report_render.normalize_active_sections(raw_sections)
        for key, cb in self.module_checkboxes.items():
            cb.setChecked(key in active_set)

        self.cb_attach_xlsx.setChecked(cfg.get("ATTACH_XLSX", "true").lower() in ("true", "1", "yes"))
        self.cb_attach_csv.setChecked(cfg.get("ATTACH_CSV", "true").lower() in ("true", "1", "yes"))

        sched_t = cfg.get("SCHEDULE_TIME", "07:00")
        qt = QTime.fromString(sched_t, "HH:mm")
        if not qt.isValid():
            qt = QTime.fromString(sched_t, "hh:mm AP")
        if qt.isValid():
            self.time_schedule.setTime(qt)
        else:
            self.time_schedule.setTime(QTime(7, 0))

        self.cb_schedule_enabled.setChecked(cfg.get("SCHEDULE_ENABLED", "true").lower() in ("true", "1", "yes"))

        self.txt_github_repo.setText(cfg.get("GITHUB_REPO", "0784harshil/specializedreporting"))
        self.cb_auto_check_updates.setChecked(cfg.get("AUTO_CHECK_UPDATES", "true").lower() in ("true", "1", "yes"))

    def collect_ui_settings(self) -> dict[str, str]:
        return {
            "SQL_SERVER": self.combo_server.currentText().strip(),
            "SQL_DATABASE": self.combo_database.currentText().strip(),
            "SQL_AUTH": "sql" if self.radio_auth_sql.isChecked() else "windows",
            "SQL_USER": self.txt_user.text().strip(),
            "SQL_PASSWORD": self.txt_pwd.text().strip(),
            "SMTP_HOST": self.txt_smtp_host.text().strip(),
            "SMTP_PORT": self.txt_smtp_port.text().strip(),
            "SMTP_USER": self.txt_smtp_user.text().strip(),
            "SMTP_PASSWORD": self.txt_smtp_pwd.text().strip(),
            "SMTP_FROM": self.txt_smtp_from.text().strip(),
            "SMTP_USE_TLS": "true" if self.cb_smtp_tls.isChecked() else "false",
            "REPORT_RECIPIENT": self.txt_recipients.text().strip(),
            "SMS_RECIPIENTS": self.txt_sms_recipients.text().strip(),
            "REPORT_DATE_MODE": self.cfg.get("REPORT_DATE_MODE", "yesterday"),
            "DRY_RUN": "true" if self.cb_dry_run.isChecked() else "false",
            "REPORT_SECTIONS": ",".join(sorted(self.get_selected_sections())),
            "ATTACH_XLSX": "true" if self.cb_attach_xlsx.isChecked() else "false",
            "ATTACH_CSV": "true" if self.cb_attach_csv.isChecked() else "false",
            "SCHEDULE_TIME": self.time_schedule.time().toString("HH:mm"),
            "SCHEDULE_ENABLED": "true" if self.cb_schedule_enabled.isChecked() else "false",
            "GITHUB_REPO": self.txt_github_repo.text().strip(),
            "AUTO_CHECK_UPDATES": "true" if self.cb_auto_check_updates.isChecked() else "false",
        }

    def save_settings(self):
        if not self.is_admin_unlocked:
            QMessageBox.warning(self, "Access Denied", "Please unlock Team Admin Mode to save configuration changes.")
            return

        try:
            cfg = self.collect_ui_settings()
            save_app_env(cfg)
            self.cfg = cfg
            self.log("Configuration successfully synchronized and saved to config.env and .env.", "SUCCESS")
            QMessageBox.information(self, "Configuration Saved", "✅ Settings successfully saved to config.env and .env!")
        except Exception as e:
            self.log(f"Failed saving configuration: {e}", "ERROR")
            QMessageBox.critical(self, "Save Error", f"❌ Failed to save configuration:\n{e}")

    # -----------------------------------------------------------------------
    # Database Actions
    # -----------------------------------------------------------------------
    def discover_instances(self):
        self.log("Scanning system registry and network for SQL Server instances...")
        instances = report_db.discover_local_sql_instances()
        current = self.combo_server.currentText()
        self.combo_server.clear()
        self.combo_server.addItems(instances)
        if current in instances:
            self.combo_server.setCurrentText(current)
        self.log(f"Discovered {len(instances)} instance(s): {', '.join(instances)}", "SUCCESS")
        QMessageBox.information(self, "Discovery Complete", f"Found {len(instances)} SQL Server instance(s) on this machine.")

    def fetch_databases_list(self):
        server = self.combo_server.currentText().strip()
        auth = "sql" if self.radio_auth_sql.isChecked() else "windows"
        user = self.txt_user.text().strip()
        pwd = self.txt_pwd.text().strip()
        
        self.log(f"Fetching database catalog from {server}...")
        try:
            with report_db.open_connection(server, "master", auth, user, pwd) as conn:
                dbs = report_db.fetch_server_databases(conn)
                self.combo_database.clear()
                self.combo_database.addItems(dbs)
                if "cresqlvick" in dbs:
                    self.combo_database.setCurrentText("cresqlvick")
                self.log(f"Catalog fetched: {len(dbs)} database(s) found.", "SUCCESS")
                QMessageBox.information(self, "Databases Fetched", f"Found {len(dbs)} database(s) on server {server}.")
        except Exception as e:
            self.log(f"Failed fetching databases: {e}", "ERROR")
            QMessageBox.warning(self, "Database Fetch Error", f"Could not list databases:\n{e}")

    def test_db_connection(self):
        server = self.combo_server.currentText().strip()
        database = self.combo_database.currentText().strip()
        auth = "sql" if self.radio_auth_sql.isChecked() else "windows"
        user = self.txt_user.text().strip()
        pwd = self.txt_pwd.text().strip()

        self.log(f"Testing connection to {server}/{database} ({auth})...")
        ok, msg = report_db.test_connection(server, database, auth, user, pwd)
        if ok:
            self.lbl_side_db_chip.setText(f"🟢 SQL: {server}")
            self.lbl_side_db_chip.setStyleSheet("color: #10b981; font-weight: bold; font-size: 11px;")
            self.lbl_header_db_badge.setText(f"{server} / {database}")
            self.log(f"Database connection verified: {msg}", "SUCCESS")
            QMessageBox.information(self, "Connection Successful", f"✅ {msg}")
        else:
            self.lbl_side_db_chip.setText("🔴 SQL: Disconnected")
            self.lbl_side_db_chip.setStyleSheet("color: #ef4444; font-weight: bold; font-size: 11px;")
            self.log(f"Database connection failed: {msg}", "ERROR")
            QMessageBox.critical(self, "Connection Failed", f"❌ Connection test failed:\n\n{msg}")

    def auto_connect_on_startup(self):
        server = self.combo_server.currentText().strip()
        database = self.combo_database.currentText().strip()
        auth = "sql" if self.radio_auth_sql.isChecked() else "windows"
        user = self.txt_user.text().strip()
        pwd = self.txt_pwd.text().strip()

        self.fetch_worker = DbFetchWorker(server, database, auth, user, pwd)
        self.fetch_worker.summary_ready.connect(self.on_server_summary_received)
        self.fetch_worker.log_msg.connect(lambda m: self.log(m, "INFO"))
        self.fetch_worker.start()

    def auto_fetch_server_details(self):
        server = self.combo_server.currentText().strip()
        database = self.combo_database.currentText().strip()
        auth = "sql" if self.radio_auth_sql.isChecked() else "windows"
        user = self.txt_user.text().strip()
        pwd = self.txt_pwd.text().strip()

        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)
        self.fetch_worker = DbFetchWorker(server, database, auth, user, pwd)
        self.fetch_worker.summary_ready.connect(self.on_server_summary_received)
        self.fetch_worker.error.connect(self.on_server_fetch_error)
        self.fetch_worker.log_msg.connect(lambda m: self.log(m, "INFO"))
        self.fetch_worker.start()

    def on_server_summary_received(self, summary: dict):
        self.progress_bar.setVisible(False)
        stores = summary.get("stores", [])
        self.cached_stores = stores
        
        self.table_stores.setRowCount(len(stores))
        self.combo_run_store.clear()
        self.combo_run_store.addItem(f"All Stores ({len(stores)} store{'s' if len(stores) != 1 else ''})", None)

        for row_idx, st in enumerate(stores):
            st_id = st.get("store_id", "")
            st_name = st.get("store_name", "")
            self.table_stores.setItem(row_idx, 0, QTableWidgetItem(st_id))
            self.table_stores.setItem(row_idx, 1, QTableWidgetItem(st_name))
            self.table_stores.setItem(row_idx, 2, QTableWidgetItem(st.get("address", "")))
            self.table_stores.setItem(row_idx, 3, QTableWidgetItem(st.get("phone", "")))
            self.table_stores.setItem(row_idx, 4, QTableWidgetItem(st.get("email", "")))

            self.combo_run_store.addItem(f"Store {st_id} — {st_name}", st_id)

        latest_s = summary.get("latest_sales_date")
        latest_c = summary.get("latest_clock_date")
        self.latest_db_sales_date = latest_s
        self.latest_db_clock_date = latest_c
        self.lbl_latest_sales.setText(f"Latest Sales Date: {latest_s or 'None found'}")
        self.lbl_latest_clock.setText(f"Latest TimeClock Date: {latest_c or 'None found'}")

        server = self.combo_server.currentText().strip()
        database = self.combo_database.currentText().strip()
        self.lbl_side_db_chip.setText(f"🟢 SQL: {server}")
        self.lbl_side_db_chip.setStyleSheet("color: #10b981; font-weight: bold; font-size: 11px;")
        self.lbl_side_store_chip.setText(f"🏪 Stores: {len(stores)} in dbo.Setup")

        if latest_s:
            qd = QDate.fromString(latest_s, "yyyy-MM-dd")
            if qd.isValid() and self.combo_date_preset.currentText() == "Latest Date in DB":
                self.dt_start.setDate(qd)
                self.dt_end.setDate(qd)

    def on_server_fetch_error(self, err: str):
        self.progress_bar.setVisible(False)
        self.lbl_side_db_chip.setText("🔴 SQL: Error")
        self.lbl_side_db_chip.setStyleSheet("color: #ef4444; font-weight: bold; font-size: 11px;")
        self.log(f"Auto-fetch failure: {err}", "ERROR")
        QMessageBox.critical(self, "Auto-Fetch Error", f"❌ Failed to fetch details from SQL Server:\n\n{err}")

    # -----------------------------------------------------------------------
    # Email Actions
    # -----------------------------------------------------------------------
    def send_test_email(self):
        smtp_cfg = report_mailer.SmtpConfig(
            host=self.txt_smtp_host.text().strip(),
            port=int(self.txt_smtp_port.text().strip() or 587),
            user=self.txt_smtp_user.text().strip(),
            password=self.txt_smtp_pwd.text().strip(),
            from_addr=self.txt_smtp_from.text().strip(),
            use_tls=self.cb_smtp_tls.isChecked(),
        )
        err = smtp_cfg.validate()
        if err:
            QMessageBox.warning(self, "SMTP Validation Error", f"Incomplete SMTP configuration:\n\n{err}")
            return

        recipients = [r.strip() for r in re.split(r"[,;\s]+", self.txt_recipients.text().strip()) if r.strip() and "@" in r]
        if not recipients:
            QMessageBox.warning(self, "No Recipients", "Please enter at least one valid recipient email address.")
            return

        self.log(f"Sending SMTP verification email to: {', '.join(recipients)}...")
        job = report_mailer.EmailJob(
            to=recipients,
            cc=[],
            bcc=[],
            subject="Verification Test — Specialized Reporting",
            html_body="""<div style="font-family: Arial, sans-serif; padding: 20px; color: #222;">
                <h2 style="color: #2563eb;">✅ SMTP Connection Verified</h2>
                <p>This is a verification email from your <strong>Specialized Reporting</strong> application.</p>
                <p><strong>Your SMTP credentials and recipient configuration are working properly!</strong></p>
            </div>""",
            attachments=[],
        )

        try:
            report_mailer.send(smtp_cfg, job)
            self.log("SMTP verification email sent successfully!", "SUCCESS")
            QMessageBox.information(self, "Test Email Sent", f"✅ Test email successfully sent to:\n{', '.join(recipients)}")
        except Exception as e:
            self.log(f"SMTP dispatch failure: {e}", "ERROR")
            QMessageBox.critical(self, "Email Dispatch Failed", f"❌ Failed to send test email:\n\n{e}")

    # -----------------------------------------------------------------------
    # Report Generation & Live Explorer
    # -----------------------------------------------------------------------
    def generate_and_preview_report(self):
        server = self.combo_server.currentText().strip()
        database = self.combo_database.currentText().strip()
        auth = "sql" if self.radio_auth_sql.isChecked() else "windows"
        user = self.txt_user.text().strip()
        pwd = self.txt_pwd.text().strip()

        st_id = self.combo_run_store.currentData()
        start_d = self.dt_start.date().toPython()
        end_d = self.dt_end.date().toPython()

        if start_d > end_d:
            QMessageBox.warning(self, "Date Error", "Start Date cannot be after End Date.")
            return

        active_sections = self.get_selected_sections()
        if not active_sections:
            QMessageBox.warning(self, "No Modules Selected", "Please select at least one module section in the Modules tab.")
            return

        attach_xlsx = self.cb_attach_xlsx.isChecked()
        attach_csv = self.cb_attach_csv.isChecked()

        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)
        self.btn_generate_preview.setEnabled(False)

        self.report_worker = ReportGenerateWorker(
            server, database, auth, user, pwd,
            st_id, start_d, end_d, active_sections, attach_xlsx, attach_csv
        )
        self.report_worker.report_ready.connect(self.on_report_generated)
        self.report_worker.error.connect(self.on_report_error)
        self.report_worker.log_msg.connect(lambda m: self.log(m, "INFO"))
        self.report_worker.start()

    def on_report_generated(self, bundles: list[ReportBundle], generated_files: list[dict], metrics: dict):
        self.progress_bar.setVisible(False)
        self.btn_generate_preview.setEnabled(True)

        self.latest_bundles = bundles
        self.latest_generated_files = generated_files

        self.dash_invoices.setText(f"{int(metrics.get('invoices', 0)):,}")
        self.dash_gross.setText(f"${float(metrics.get('gross_sales', 0)):,.2f}")
        self.dash_avg.setText(f"${float(metrics.get('avg_ticket', 0)):,.2f}")
        self.dash_tax.setText(f"${float(metrics.get('sales_tax', 0)):,.2f}")
        self.dash_cash.setText(f"${float(metrics.get('cash_collected', 0)):,.2f}")

        if bundles:
            b0 = bundles[0]
            if not b0.top_items.empty:
                self.dash_table_items.setRowCount(len(b0.top_items.head(10)))
                for r_idx, (_, r) in enumerate(b0.top_items.head(10).iterrows()):
                    self.dash_table_items.setItem(r_idx, 0, QTableWidgetItem(f"#{r_idx+1}"))
                    self.dash_table_items.setItem(r_idx, 1, QTableWidgetItem(str(r.get("ItemName_Desc", ""))))
                    self.dash_table_items.setItem(r_idx, 2, QTableWidgetItem(str(r.get("total_quantity", 0))))
                    self.dash_table_items.setItem(r_idx, 3, QTableWidgetItem(f"${float(r.get('total_revenue', 0)):,.2f}"))

            if not b0.by_department.empty:
                self.dash_table_dept.setRowCount(len(b0.by_department))
                for r_idx, (_, r) in enumerate(b0.by_department.iterrows()):
                    self.dash_table_dept.setItem(r_idx, 0, QTableWidgetItem(str(r.get("dept_id", ""))))
                    self.dash_table_dept.setItem(r_idx, 1, QTableWidgetItem(str(r.get("dept_name", ""))))
                    self.dash_table_dept.setItem(r_idx, 2, QTableWidgetItem(str(r.get("total_quantity", 0))))
                    self.dash_table_dept.setItem(r_idx, 3, QTableWidgetItem(f"${float(r.get('total_revenue', 0)):,.2f}"))

            if not b0.transactions.empty:
                self.table_tx.setRowCount(len(b0.transactions))
                for r_idx, (_, r) in enumerate(b0.transactions.iterrows()):
                    self.table_tx.setItem(r_idx, 0, QTableWidgetItem(str(r.get("Invoice_Number", ""))))
                    self.table_tx.setItem(r_idx, 1, QTableWidgetItem(str(r.get("Invoice_Date_Time", ""))))
                    self.table_tx.setItem(r_idx, 2, QTableWidgetItem(str(r.get("Cashier_ID", ""))))
                    self.table_tx.setItem(r_idx, 3, QTableWidgetItem(str(r.get("ItemName_Desc", ""))))
                    self.table_tx.setItem(r_idx, 4, QTableWidgetItem(str(r.get("Quantity", 1))))
                    self.table_tx.setItem(r_idx, 5, QTableWidgetItem(f"${float(r.get('Price', 0)):,.2f}"))
                    self.table_tx.setItem(r_idx, 6, QTableWidgetItem(f"${float(r.get('Extended_Price', 0)):,.2f}"))
                    self.table_tx.setItem(r_idx, 7, QTableWidgetItem(f"${float(r.get('Tax_1', 0)):,.2f}"))

            if not b0.employees.empty:
                self.table_emp.setRowCount(len(b0.employees))
                for r_idx, (_, r) in enumerate(b0.employees.iterrows()):
                    self.table_emp.setItem(r_idx, 0, QTableWidgetItem(str(r.get("Emp_ID", ""))))
                    self.table_emp.setItem(r_idx, 1, QTableWidgetItem(str(r.get("Employee_Name", ""))))
                    self.table_emp.setItem(r_idx, 2, QTableWidgetItem(str(r.get("Time_In", ""))))
                    self.table_emp.setItem(r_idx, 3, QTableWidgetItem(str(r.get("Time_Out", ""))))
                    self.table_emp.setItem(r_idx, 4, QTableWidgetItem(f"{float(r.get('Hours_Worked', 0)):.2f} hrs"))
                    self.table_emp.setItem(r_idx, 5, QTableWidgetItem(f"${float(r.get('Hourly_Rate', 0)):,.2f}"))

            if not b0.audit_events.empty:
                self.table_audit.setRowCount(len(b0.audit_events))
                for r_idx, (_, r) in enumerate(b0.audit_events.iterrows()):
                    self.table_audit.setItem(r_idx, 0, QTableWidgetItem(str(r.get("event_type", ""))))
                    self.table_audit.setItem(r_idx, 1, QTableWidgetItem(str(r.get("Invoice_Number", ""))))
                    self.table_audit.setItem(r_idx, 2, QTableWidgetItem(str(r.get("Cashier_ID", ""))))
                    self.table_audit.setItem(r_idx, 3, QTableWidgetItem(str(r.get("ItemName_Desc", ""))))
                    self.table_audit.setItem(r_idx, 4, QTableWidgetItem(str(r.get("Old_Price", ""))))
                    self.table_audit.setItem(r_idx, 5, QTableWidgetItem(f"${float(r.get('Amount', 0)):,.2f}"))

        if generated_files:
            first_html_path = Path(generated_files[0]["html"])
            if first_html_path.exists():
                self.last_preview_html_path = str(first_html_path)
                html_content = first_html_path.read_text(encoding="utf-8")
                self.preview_browser.setHtml(html_content)

        self.log("Report rendering complete.", "SUCCESS")

    def on_report_error(self, err: str):
        self.progress_bar.setVisible(False)
        self.btn_generate_preview.setEnabled(True)
        self.log(f"Report generation error: {err}", "ERROR")
        QMessageBox.critical(self, "Report Generation Error", f"❌ Error generating report:\n\n{err}")

    def send_email_now(self):
        if not self.latest_bundles or not self.latest_generated_files:
            QMessageBox.information(self, "Generate First", "Please click 'Generate Report' before dispatching emails.")
            return

        smtp_cfg = report_mailer.SmtpConfig(
            host=self.txt_smtp_host.text().strip(),
            port=int(self.txt_smtp_port.text().strip() or 587),
            user=self.txt_smtp_user.text().strip(),
            password=self.txt_smtp_pwd.text().strip(),
            from_addr=self.txt_smtp_from.text().strip(),
            use_tls=self.cb_smtp_tls.isChecked(),
        )
        err = smtp_cfg.validate()
        if err:
            QMessageBox.warning(self, "SMTP Error", f"SMTP configuration is incomplete:\n\n{err}")
            return

        recipients = [r.strip() for r in re.split(r"[,;\s]+", self.txt_recipients.text().strip()) if r.strip() and "@" in r]
        if not recipients:
            QMessageBox.warning(self, "No Recipients", "Please enter at least one recipient email address in the Email tab.")
            return

        sms_recipients = [r.strip() for r in re.split(r"[,;\s]+", self.txt_sms_recipients.text().strip()) if r.strip() and "@" in r] if self.cb_send_sms.isChecked() else []

        active_sections = self.get_selected_sections()

        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)
        self.btn_send_email_now.setEnabled(False)

        self.email_worker = EmailSendWorker(
            smtp_cfg, self.latest_bundles, self.latest_generated_files,
            recipients, sms_recipients, active_sections
        )
        self.email_worker.sent_success.connect(self.on_email_sent_success)
        self.email_worker.error.connect(self.on_email_sent_error)
        self.email_worker.log_msg.connect(lambda m: self.log(m, "INFO"))
        self.email_worker.start()

    def on_email_sent_success(self, count: int):
        self.progress_bar.setVisible(False)
        self.btn_send_email_now.setEnabled(True)
        self.log(f"Dispatched {count} report email(s) successfully.", "SUCCESS")
        QMessageBox.information(self, "Emails Sent", f"✅ Successfully transmitted {count} store report email(s)!")

    def on_email_sent_error(self, err: str):
        self.progress_bar.setVisible(False)
        self.btn_send_email_now.setEnabled(True)
        self.log(f"Email dispatch error: {err}", "ERROR")
        QMessageBox.critical(self, "Email Error", f"❌ Failed to transmit email:\n\n{err}")

    def open_output_folder(self):
        out_path = Path(self.txt_output_dir.text().strip() or OUTPUT_ROOT)
        out_path.mkdir(parents=True, exist_ok=True)
        try:
            os.startfile(str(out_path))
        except Exception as e:
            QMessageBox.warning(self, "Folder Open Error", f"Could not open folder:\n{e}")


# ---------------------------------------------------------------------------
# App Entry Point (Dual-Mode: GUI or Background Scheduled Runner)
# ---------------------------------------------------------------------------

def main():
    # If invoked by Windows Task Scheduler with --scheduled or --cli, execute daily reporting silently
    if any(arg in sys.argv for arg in ("--scheduled", "--cli", "--run", "--cron")):
        import daily_report
        sys.exit(daily_report.main())

    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    
    font = QFont("Segoe UI", 10)
    app.setFont(font)

    if ICON_PATH.exists():
        app.setWindowIcon(QIcon(str(ICON_PATH)))

    window = ProfessionalStudioWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
