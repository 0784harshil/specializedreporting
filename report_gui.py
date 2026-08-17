"""Specialized Reporting — pcAmerica CRE (Professional Desktop Edition)

A high-performance, enterprise-grade PySide6 desktop application for pcAmerica CRE POS:
  - 100% Single-File Deployment (Only Specialized_Reporting.exe needed)
  - Self-Bootstrapping: Clean, empty defaults for fresh merchant installations
  - Crisp, High-Contrast Native UI with Visible Checkmarks and Bold Colored Buttons
  - Non-Intrusive Animated Toast Notification System
  - Streamlined 5-Tab Navigation (Primary Focus: Report Generator and Live Preview)
  - Dual-Mode Engine: Interactive Studio GUI + Background Scheduled Runner (--scheduled)
  - Branded Specialized Reporting Desktop Application with JD Gurus Emblem Icon
  - Integrated GitHub Auto-Updater and Force-Update Engine (updater.py)
  - Cryptographic Salted SHA-256 Team Password Protection and Role-Based Access Control
  - Automated Daily Schedule (07:00 AM) with 1-Click Windows Task Scheduler Sync
  - Asynchronous background QThread workers for 100% UI responsiveness
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
    QPropertyAnimation,
    QRect,
    QSize,
    QTime,
    QTimer,
    Qt,
    QThread,
    Signal,
)
from PySide6.QtGui import QColor, QFont, QIcon, QPixmap
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
    QProgressBar,
    QPushButton,
    QRadioButton,
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


def _to_py_date(val) -> _dt.date:
    """Safely convert any QDate, datetime, or date-like object into standard datetime.date."""
    if isinstance(val, _dt.date) and not isinstance(val, _dt.datetime):
        return val
    if isinstance(val, _dt.datetime):
        return val.date()
    if hasattr(val, "year") and hasattr(val, "month") and hasattr(val, "day"):
        try:
            y = val.year() if callable(val.year) else val.year
            m = val.month() if callable(val.month) else val.month
            d = val.day() if callable(val.day) else val.day
            return _dt.date(int(y), int(m), int(d))
        except Exception:
            pass
    if hasattr(val, "toPython") and callable(val.toPython):
        try:
            return val.toPython()
        except Exception:
            pass
    return _dt.date.today()


def load_app_env() -> dict[str, str]:
    """Loads configuration. If missing on a fresh machine, initializes with clean empty credentials."""
    if not CONFIG_FILE.exists() and not DOTENV_FILE.exists():
        # Fresh machine defaults — clean empty credentials for security
        default_cfg = {
            "SQL_SERVER": "",
            "SQL_DATABASE": "",
            "SQL_AUTH": "windows",
            "SQL_USER": "",
            "SQL_PASSWORD": "",
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
        "SQL_SERVER": os.getenv("SQL_SERVER", ""),
        "SQL_DATABASE": os.getenv("SQL_DATABASE", ""),
        "SQL_AUTH": os.getenv("SQL_AUTH", "windows").lower(),
        "SQL_USER": os.getenv("SQL_USER", ""),
        "SQL_PASSWORD": os.getenv("SQL_PASSWORD", ""),
        "SMTP_HOST": os.getenv("SMTP_HOST") or "smtp.gmail.com",
        "SMTP_PORT": os.getenv("SMTP_PORT") or "587",
        "SMTP_USER": os.getenv("SMTP_USER") or "harshilp.job10@gmail.com",
        "SMTP_PASSWORD": os.getenv("SMTP_PASSWORD") or "ultb bstt ebjf adrr",
        "SMTP_FROM": os.getenv("SMTP_FROM") or "Daily Reports <harshilp.job10@gmail.com>",
        "SMTP_USE_TLS": os.getenv("SMTP_USE_TLS", "true"),
        "REPORT_RECIPIENT": os.getenv("REPORT_RECIPIENT") or "harshil@jdgurus.com",
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
        f"SQL_DATABASE={cfg.get('SQL_DATABASE', '')}",
        f"SQL_AUTH={cfg.get('SQL_AUTH', 'windows')}",
        f"SQL_USER={cfg.get('SQL_USER', '')}",
        f"SQL_PASSWORD={cfg.get('SQL_PASSWORD', '')}",
        "",
        "# --- SMTP Email Settings ---",
        f"SMTP_HOST={cfg.get('SMTP_HOST', 'smtp.gmail.com')}",
        f"SMTP_PORT={cfg.get('SMTP_PORT', '587')}",
        f"SMTP_USER={cfg.get('SMTP_USER', '')}",
        f"SMTP_PASSWORD={cfg.get('SMTP_PASSWORD', '')}",
        f"SMTP_FROM={cfg.get('SMTP_FROM', '')}",
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
# Toast Notification Widget (Non-Intrusive, Modern Floating Alert)
# ---------------------------------------------------------------------------

class ToastNotification(QFrame):
    def __init__(self, parent: QWidget, title: str, message: str, toast_type: str = "success", duration_ms: int = 3500):
        super().__init__(parent)
        self.duration_ms = duration_ms
        
        if toast_type == "success":
            bg_color = "#059669"
            border_color = "#047857"
            icon = "✅"
        elif toast_type == "error":
            bg_color = "#dc2626"
            border_color = "#b91c1c"
            icon = "❌"
        elif toast_type == "warning":
            bg_color = "#d97706"
            border_color = "#b45309"
            icon = "⚠️"
        else:
            bg_color = "#2563eb"
            border_color = "#1d4ed8"
            icon = "ℹ️"

        self.setStyleSheet(f"""
            QFrame {{
                background-color: {bg_color};
                border: 1px solid {border_color};
                border-radius: 8px;
                padding: 10px 14px;
            }}
            QLabel {{
                color: #ffffff;
                font-family: 'Segoe UI Variable Text', 'Segoe UI', sans-serif;
            }}
        """)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(10, 8, 10, 8)
        layout.setSpacing(10)

        lbl_icon = QLabel(icon)
        lbl_icon.setStyleSheet("font-size: 16px; background: transparent;")
        layout.addWidget(lbl_icon)

        v_text = QVBoxLayout()
        v_text.setSpacing(2)
        
        lbl_title = QLabel(f"<b>{title}</b>")
        lbl_title.setStyleSheet("font-size: 13px; font-weight: 700; color: #ffffff; background: transparent;")
        v_text.addWidget(lbl_title)

        if message:
            lbl_msg = QLabel(message)
            lbl_msg.setStyleSheet("font-size: 12px; color: #f1f5f9; background: transparent;")
            lbl_msg.setWordWrap(True)
            v_text.addWidget(lbl_msg)

        layout.addLayout(v_text, stretch=1)

        btn_close = QPushButton("✕")
        btn_close.setFixedSize(22, 22)
        btn_close.setStyleSheet("""
            QPushButton {
                background: transparent;
                color: #ffffff;
                font-weight: bold;
                font-size: 12px;
                border: none;
                border-radius: 11px;
            }
            QPushButton:hover {
                background-color: rgba(255, 255, 255, 0.2);
            }
        """)
        btn_close.clicked.connect(self.close_toast)
        layout.addWidget(btn_close)

        self.setFixedWidth(380)
        self.adjustSize()
        self.update_position()

        self.timer = QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.timeout.connect(self.close_toast)
        self.timer.start(self.duration_ms)

    def update_position(self):
        if self.parent():
            p_geom = self.parent().rect()
            x = p_geom.width() - self.width() - 24
            y = 20
            self.move(x, y)

    def close_toast(self):
        self.timer.stop()
        self.hide()
        self.deleteLater()


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
            if not self.server:
                return
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
                color: #ffffff !important;
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
            self.btn_cancel.setStyleSheet("background-color: #f1f5f9; color: #475569 !important; border: 1px solid #cbd5e1;")
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
            self.btn_cancel.setStyleSheet("background-color: #f1f5f9; color: #475569 !important; border: 1px solid #cbd5e1;")
            self.btn_cancel.clicked.connect(self.reject)

            btn_box.addWidget(self.btn_change)
            btn_box.addWidget(self.btn_cancel)
            layout.addLayout(btn_box)

    def verify_and_accept(self):
        entered = self.txt_pwd.text().strip()
        if auth_guard.verify_team_password(entered):
            self.accept()
        else:
            if self.parent() and hasattr(self.parent(), "show_toast"):
                self.parent().show_toast("Access Denied", "Incorrect team password.", "error")
            self.reject()

    def change_password_and_accept(self):
        curr = self.txt_current.text().strip()
        new_p = self.txt_new.text().strip()
        conf = self.txt_confirm.text().strip()

        if not auth_guard.verify_team_password(curr):
            if self.parent() and hasattr(self.parent(), "show_toast"):
                self.parent().show_toast("Verification Failed", "Current password is incorrect.", "error")
            return

        if len(new_p) < 4:
            if self.parent() and hasattr(self.parent(), "show_toast"):
                self.parent().show_toast("Invalid Password", "Password must be at least 4 characters.", "warning")
            return

        if new_p != conf:
            if self.parent() and hasattr(self.parent(), "show_toast"):
                self.parent().show_toast("Mismatch", "New password and confirmation do not match.", "warning")
            return

        if auth_guard.change_team_password(new_p):
            if self.parent() and hasattr(self.parent(), "show_toast"):
                self.parent().show_toast("Password Updated", "Team master password successfully updated!", "success")
            self.accept()


# ---------------------------------------------------------------------------
# Modern High-Contrast Stylesheet
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
    padding: 14px 14px 12px 14px;
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
    color: #ffffff !important;
    font-weight: 600;
    border: none;
    border-radius: 6px;
    padding: 8px 16px;
    min-height: 22px;
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
    color: #94a3b8 !important;
}

QPushButton.btnSecondary {
    background-color: #f1f5f9;
    color: #1e293b !important;
    border: 1px solid #cbd5e1;
}
QPushButton.btnSecondary:hover {
    background-color: #e2e8f0;
    color: #0f172a !important;
}

QPushButton.btnSuccess {
    background-color: #059669;
    color: #ffffff !important;
    font-weight: 700;
}
QPushButton.btnSuccess:hover {
    background-color: #047857;
}

QPushButton.btnAccent {
    background-color: #4f46e5;
    color: #ffffff !important;
    font-weight: 700;
}
QPushButton.btnAccent:hover {
    background-color: #4338ca;
}

QCheckBox, QRadioButton {
    spacing: 8px;
    font-weight: 500;
    color: #334155;
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
    padding: 8px 16px;
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
        self.resize(1280, 820)
        self.setMinimumSize(960, 640)

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

        # Connect if SQL Server is configured
        if self.cfg.get("SQL_SERVER"):
            self.auto_connect_on_startup()

        # Check for remote updates quietly if enabled
        if self.cfg.get("AUTO_CHECK_UPDATES", "true").lower() in ("true", "1", "yes"):
            self.trigger_background_update_check(silent=True)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        for child in self.findChildren(ToastNotification):
            child.update_position()

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

    def show_toast(self, title: str, message: str = "", toast_type: str = "success"):
        """Displays a modern, non-intrusive floating toast notification."""
        t = ToastNotification(self, title, message, toast_type)
        t.show()

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
            self.show_toast("Admin Mode Unlocked", "Full IT/Support settings editing unlocked.", "success")
            self.log("IT / Support Team authenticated successfully.", "SUCCESS")
        else:
            self.is_admin_unlocked = False
            self.apply_lock_state()

    def toggle_lock_state(self):
        if self.is_admin_unlocked:
            self.is_admin_unlocked = False
            self.apply_lock_state()
            self.show_toast("Restricted Mode", "Admin settings locked for merchant safety.", "info")
            self.log("Admin privileges locked by user.", "INFO")
        else:
            self.prompt_team_login()

    def apply_lock_state(self):
        unlocked = self.is_admin_unlocked
        
        if unlocked:
            self.btn_lock_status.setText("🔓 Team Mode (Active)")
            self.btn_lock_status.setStyleSheet("background-color: #10b981; color: white !important; font-weight: bold; padding: 6px 14px; border-radius: 6px;")
            self.lbl_lock_banner.setVisible(False)
        else:
            self.btn_lock_status.setText("🔒 Restricted Mode (Click to Unlock)")
            self.btn_lock_status.setStyleSheet("background-color: #ef4444; color: white !important; font-weight: bold; padding: 6px 14px; border-radius: 6px;")
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
    # Shell UI Layout & Navigation (Clean 5 Tabs, Responsive)
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
        sidebar_frame.setFixedWidth(250)
        side_vbox = QVBoxLayout(sidebar_frame)
        side_vbox.setContentsMargins(14, 18, 14, 16)
        side_vbox.setSpacing(12)

        brand_hbox = QHBoxLayout()
        lbl_logo = QLabel()
        if ICON_PATH.exists():
            pix = QPixmap(str(ICON_PATH)).scaled(36, 36, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            lbl_logo.setPixmap(pix)
        else:
            lbl_logo.setText("📊")
            lbl_logo.setStyleSheet("font-size: 22px;")

        brand_vbox = QVBoxLayout()
        lbl_app_name = QLabel("Specialized")
        lbl_app_name.setStyleSheet("color: #ffffff; font-size: 16px; font-weight: 800; letter-spacing: 0.5px;")
        lbl_app_sub = QLabel("Reporting System")
        lbl_app_sub.setStyleSheet("color: #38bdf8; font-size: 12px; font-weight: 700;")
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
        self.nav_list.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        
        nav_items = [
            ("🚀  Report Generator", 0),
            ("🧩  Module Filter", 1),
            ("🔌  SQL Server Discovery", 2),
            ("📧  Email Dispatch", 3),
            ("⚙️  Settings & Schedule", 4),
        ]
        for label, idx in nav_items:
            item = QListWidgetItem(label)
            item.setSizeHint(QSize(200, 42))
            self.nav_list.addItem(item)

        self.nav_list.currentRowChanged.connect(self.switch_view)
        side_vbox.addWidget(self.nav_list, stretch=1)

        # Side Status Card
        status_card = QFrame()
        status_card.setStyleSheet("background-color: #1e293b; border-radius: 8px; padding: 10px;")
        sc_vbox = QVBoxLayout(status_card)
        sc_vbox.setSpacing(6)
        
        self.lbl_side_db_chip = QLabel("🔴 SQL: Not Configured")
        self.lbl_side_db_chip.setStyleSheet("color: #ef4444; font-weight: bold; font-size: 11px;")
        self.lbl_side_store_chip = QLabel("🏪 Stores: Ready")
        self.lbl_side_store_chip.setStyleSheet("color: #94a3b8; font-size: 11px;")
        self.lbl_side_ver_chip = QLabel(f"⚡ App Version: v{updater.CURRENT_VERSION}")
        self.lbl_side_ver_chip.setStyleSheet("color: #38bdf8; font-size: 10px; font-weight: 600;")
        
        sc_vbox.addWidget(self.lbl_side_db_chip)
        sc_vbox.addWidget(self.lbl_side_store_chip)
        sc_vbox.addWidget(self.lbl_side_ver_chip)
        side_vbox.addWidget(status_card)

        self.btn_save_top = QPushButton("💾 Save Config")
        self.btn_save_top.setStyleSheet("background-color: #059669; color: white !important; font-weight: bold; padding: 8px; border-radius: 6px;")
        self.btn_save_top.clicked.connect(self.save_settings)
        side_vbox.addWidget(self.btn_save_top)

        root_layout.addWidget(sidebar_frame)

        # 2. Main Content Area
        content_widget = QWidget()
        content_widget.setObjectName("contentArea")
        content_layout = QVBoxLayout(content_widget)
        content_layout.setContentsMargins(18, 14, 18, 12)
        content_layout.setSpacing(10)

        # Top Bar
        top_bar = QFrame()
        top_bar.setStyleSheet("background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 6px 12px;")
        top_layout = QHBoxLayout(top_bar)
        top_layout.setContentsMargins(6, 4, 6, 4)

        self.lbl_page_title = QLabel("Report Generator and Live Preview")
        self.lbl_page_title.setStyleSheet("font-size: 17px; font-weight: 800; color: #0f172a;")
        top_layout.addWidget(self.lbl_page_title)

        top_layout.addStretch()

        self.btn_lock_status = QPushButton("🔒 Restricted Mode (Click to Unlock)")
        self.btn_lock_status.clicked.connect(self.toggle_lock_state)
        top_layout.addWidget(self.btn_lock_status)

        self.lbl_header_db_badge = QLabel("Server: Ready")
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
        self.frame_update_banner.setStyleSheet("background-color: #eff6ff; border: 1.5px solid #3b82f6; border-radius: 8px; padding: 6px 12px;")
        ub_layout = QHBoxLayout(self.frame_update_banner)
        ub_layout.setContentsMargins(4, 2, 4, 2)
        self.lbl_update_banner_text = QLabel("⭐ <b>A new software update is available!</b>")
        self.lbl_update_banner_text.setStyleSheet("color: #1e3a8a; font-size: 12px;")
        ub_layout.addWidget(self.lbl_update_banner_text)
        ub_layout.addStretch()
        self.btn_banner_update_now = QPushButton("⚡ Update Now")
        self.btn_banner_update_now.setStyleSheet("background-color: #2563eb; color: white !important; font-weight: bold; padding: 4px 12px; font-size: 11px;")
        self.btn_banner_update_now.clicked.connect(self.execute_update_process)
        ub_layout.addWidget(self.btn_banner_update_now)
        content_layout.addWidget(self.frame_update_banner)

        self.lbl_lock_banner = QLabel("🔒 Restricted Merchant Mode: Settings and credentials are protected. Click 'Unlock' above to modify system configuration.")
        self.lbl_lock_banner.setStyleSheet("background-color: #fff7ed; color: #c2410c; border: 1px solid #fed7aa; border-radius: 6px; padding: 5px 10px; font-weight: 600; font-size: 12px;")
        content_layout.addWidget(self.lbl_lock_banner)

        # Stacked Pages
        self.stack = QStackedWidget()
        content_layout.addWidget(self.stack, stretch=1)

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

        # Bottom Activity Console Drawer
        self.console_frame = QFrame()
        self.console_frame.setStyleSheet("background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px;")
        c_vbox = QVBoxLayout(self.console_frame)
        c_vbox.setContentsMargins(8, 6, 8, 6)
        c_vbox.setSpacing(4)

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
        self.txt_log_console.setFixedHeight(60)
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
            "Report Generator and Live Preview",
            "Module and Section Filter",
            "SQL Server and Auto-Discovery",
            "Email and SMTP Dispatch",
            "System Settings and Automated Scheduling",
        ]
        if 0 <= row < len(titles):
            self.lbl_page_title.setText(titles[row])
            self.stack.setCurrentIndex(row)

    def toggle_console_drawer(self):
        is_visible = self.txt_log_console.isVisible()
        self.txt_log_console.setVisible(not is_visible)
        self.btn_toggle_console.setText("Hide Log" if not is_visible else "Show Log")

    # -----------------------------------------------------------------------
    # View 0: Report Generator and Live Preview (High-Contrast Buttons)
    # -----------------------------------------------------------------------
    def setup_generator_view(self):
        layout = QVBoxLayout(self.view_generator)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        ctrl_frame = QFrame()
        ctrl_frame.setProperty("class", "cardFrame")
        ctrl_frame.setStyleSheet("background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 8px;")
        ctrl_layout = QHBoxLayout(ctrl_frame)
        ctrl_layout.setContentsMargins(6, 4, 6, 4)
        ctrl_layout.setSpacing(10)

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

        # High-Contrast Vibrant Buttons
        self.btn_generate_preview = QPushButton("🚀 Generate Report")
        self.btn_generate_preview.setMinimumWidth(140)
        self.btn_generate_preview.setStyleSheet("""
            QPushButton {
                background-color: #059669;
                color: #ffffff !important;
                font-weight: 700;
                font-size: 12px;
                padding: 7px 14px;
                border-radius: 6px;
                border: none;
            }
            QPushButton:hover {
                background-color: #047857;
            }
        """)
        self.btn_generate_preview.clicked.connect(self.generate_and_preview_report)
        ctrl_layout.addWidget(self.btn_generate_preview)

        self.btn_send_email_now = QPushButton("✉️ Dispatch Email")
        self.btn_send_email_now.setMinimumWidth(130)
        self.btn_send_email_now.setStyleSheet("""
            QPushButton {
                background-color: #4f46e5;
                color: #ffffff !important;
                font-weight: 700;
                font-size: 12px;
                padding: 7px 14px;
                border-radius: 6px;
                border: none;
            }
            QPushButton:hover {
                background-color: #4338ca;
            }
        """)
        self.btn_send_email_now.clicked.connect(self.send_email_now)
        ctrl_layout.addWidget(self.btn_send_email_now)

        layout.addWidget(ctrl_frame)

        self.preview_tabs = QTabWidget()

        # Tab 1: Instant Native HTML Document Browser
        tab_html = QWidget()
        th_vbox = QVBoxLayout(tab_html)
        th_vbox.setContentsMargins(4, 4, 4, 4)

        th_toolbar = QHBoxLayout()
        lbl_p_info = QLabel("<b>Instant Email Layout Preview</b> (Formatting, KPIs and Tables)")
        lbl_p_info.setStyleSheet("color: #475569; font-size: 12px;")
        th_toolbar.addWidget(lbl_p_info)
        th_toolbar.addStretch()

        self.btn_open_in_browser = QPushButton("🌐 Open in Web Browser (Edge / Chrome)")
        self.btn_open_in_browser.setProperty("class", "btnSecondary")
        self.btn_open_in_browser.clicked.connect(self.open_current_report_in_browser)
        th_toolbar.addWidget(self.btn_open_in_browser)
        th_vbox.addLayout(th_toolbar)

        self.preview_browser = QTextBrowser()
        self.preview_browser.setStyleSheet("border: 1px solid #e2e8f0; border-radius: 6px; background-color: #ffffff; padding: 8px;")
        self.preview_browser.setOpenExternalLinks(True)
        th_vbox.addWidget(self.preview_browser)
        self.preview_tabs.addTab(tab_html, "📄 Rendered HTML Email Layout")

        # Tab 2: Itemized Transactions Table
        tab_tx = QWidget()
        tx_vbox = QVBoxLayout(tab_tx)
        tx_vbox.setContentsMargins(4, 4, 4, 4)
        self.table_tx = QTableWidget(0, 8)
        self.table_tx.setHorizontalHeaderLabels(["Invoice #", "Timestamp", "Cashier", "Item Name", "Qty", "Price", "Ext Price", "Tax"])
        self.table_tx.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        self.table_tx.setAlternatingRowColors(True)
        tx_vbox.addWidget(self.table_tx)
        self.preview_tabs.addTab(tab_tx, "🧾 Itemized Transactions")

        # Tab 3: Employee Time Clock
        tab_emp = QWidget()
        emp_vbox = QVBoxLayout(tab_emp)
        emp_vbox.setContentsMargins(4, 4, 4, 4)
        self.table_emp = QTableWidget(0, 6)
        self.table_emp.setHorizontalHeaderLabels(["Emp ID", "Employee Name", "Clock In", "Clock Out", "Total Hours", "Hourly Wage"])
        self.table_emp.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.table_emp.setAlternatingRowColors(True)
        emp_vbox.addWidget(self.table_emp)
        self.preview_tabs.addTab(tab_emp, "👥 Employee TimeClock")

        # Tab 4: Audit and Loss Prevention
        tab_audit = QWidget()
        aud_vbox = QVBoxLayout(tab_audit)
        aud_vbox.setContentsMargins(4, 4, 4, 4)
        self.table_audit = QTableWidget(0, 6)
        self.table_audit.setHorizontalHeaderLabels(["Event Type", "Invoice #", "Cashier", "Item / Details", "Old / Overridden", "Amount ($)"])
        self.table_audit.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        self.table_audit.setAlternatingRowColors(True)
        aud_vbox.addWidget(self.table_audit)
        self.preview_tabs.addTab(tab_audit, "🛡️ Loss Prevention and Audit")

        layout.addWidget(self.preview_tabs, stretch=1)

    def open_current_report_in_browser(self):
        if self.last_preview_html_path and Path(self.last_preview_html_path).exists():
            webbrowser.open(Path(self.last_preview_html_path).as_uri())
        else:
            self.show_toast("Notice", "Please click 'Generate Report' first.", "info")

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
    # View 1: Modular Filter and Sections (Polished Rich-Text Rows)
    # -----------------------------------------------------------------------
    def setup_modules_view(self):
        layout = QVBoxLayout(self.view_modules)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(10)

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

        grid_modules = QGridLayout()
        grid_modules.setSpacing(10)

        self.module_checkboxes: dict[str, QCheckBox] = {}

        # 1. Sales Performance Box
        grp_sales = QGroupBox("📊 Sales Performance and Analytics")
        v_sales = QVBoxLayout(grp_sales)
        v_sales.setSpacing(6)
        sales_items = [
            ("kpis", "Key Metrics / KPIs", "Invoice count, Gross/Net Sales, Avg Ticket, Tax, Cash"),
            ("departments", "Sales by Department", "Departmental item quantities, sales and fixed taxes"),
            ("fixed_tax", "Fixed Tax Buckets", "Sales grouped by Fixed Tax amount ($0.15, $0.30)"),
            ("top_items", "Top 20 Best Sellers", "Highest revenue generating items sold"),
            ("hourly", "Hourly Sales Curve", "Hourly transaction volume and invoice count"),
            ("payments", "Payment Breakdown", "Cash, Credit Card, Debit, Check, Gift Card"),
        ]
        for sec_key, title, d_text in sales_items:
            row_widget = QWidget()
            row_layout = QHBoxLayout(row_widget)
            row_layout.setContentsMargins(0, 2, 0, 2)
            row_layout.setSpacing(8)

            cb = QCheckBox()
            cb.setChecked(True)
            self.module_checkboxes[sec_key] = cb

            lbl = QLabel(f"<b>{title}</b> — <span style='color:#64748b; font-size:12px;'>{d_text}</span>")
            lbl.setTextFormat(Qt.TextFormat.RichText)
            lbl.setStyleSheet("background: transparent; font-size: 13px;")

            row_layout.addWidget(cb)
            row_layout.addWidget(lbl, stretch=1)
            v_sales.addWidget(row_widget)
        grid_modules.addWidget(grp_sales, 0, 0)

        # 2. Staff and Loss Prevention Box
        grp_ops = QGroupBox("👥 Staff and Loss Prevention Audit")
        v_ops = QVBoxLayout(grp_ops)
        v_ops.setSpacing(6)
        ops_items = [
            ("employees", "Employee TimeClock", "Staff shifts, clock-in/out timestamps, hours, wages"),
            ("voids", "Transaction and Line Voids", "Voided invoices with cashier ID, timestamp, amount"),
            ("price_changes", "Price Overrides", "Manual price changes with original price and difference"),
            ("deletes", "Line Item Deletions", "Items deleted before invoice completion"),
            ("transactions", "Itemized Detail CSV", "Full itemized line-by-line transaction journal"),
        ]
        for sec_key, title, d_text in ops_items:
            row_widget = QWidget()
            row_layout = QHBoxLayout(row_widget)
            row_layout.setContentsMargins(0, 2, 0, 2)
            row_layout.setSpacing(8)

            cb = QCheckBox()
            cb.setChecked(True)
            self.module_checkboxes[sec_key] = cb

            lbl = QLabel(f"<b>{title}</b> — <span style='color:#64748b; font-size:12px;'>{d_text}</span>")
            lbl.setTextFormat(Qt.TextFormat.RichText)
            lbl.setStyleSheet("background: transparent; font-size: 13px;")

            row_layout.addWidget(cb)
            row_layout.addWidget(lbl, stretch=1)
            v_ops.addWidget(row_widget)
        grid_modules.addWidget(grp_ops, 0, 1)

        layout.addLayout(grid_modules)

        # 3. Attachments Box
        grp_attach = QGroupBox("📎 Attachment and Notification Delivery Options")
        att_hbox = QHBoxLayout(grp_attach)
        att_hbox.setContentsMargins(12, 12, 12, 12)
        att_hbox.setSpacing(20)

        self.cb_attach_xlsx = QCheckBox("Include Styled Excel (.xlsx) Multi-Sheet Workbook")
        self.cb_attach_xlsx.setChecked(True)
        att_hbox.addWidget(self.cb_attach_xlsx)

        self.cb_attach_csv = QCheckBox("Include Raw CSV Detail Files (Transactions and Shifts)")
        self.cb_attach_csv.setChecked(True)
        att_hbox.addWidget(self.cb_attach_csv)

        self.cb_send_sms = QCheckBox("Send Mobile Text Summary via SMS Gateways")
        self.cb_send_sms.setChecked(False)
        att_hbox.addWidget(self.cb_send_sms)
        att_hbox.addStretch()

        layout.addWidget(grp_attach)
        layout.addStretch()

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
    # View 2: SQL Server Connection and Discovery
    # -----------------------------------------------------------------------
    def setup_sql_view(self):
        layout = QVBoxLayout(self.view_sql)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        grp_conn = QGroupBox("SQL Server Database Connection")
        g_layout = QGridLayout(grp_conn)
        g_layout.setSpacing(10)
        g_layout.setContentsMargins(14, 16, 14, 14)

        g_layout.addWidget(QLabel("SQL Server Instance:"), 0, 0)
        self.combo_server = QComboBox()
        self.combo_server.setEditable(True)
        self.combo_server.setPlaceholderText("e.g. .\\pcamerica or localhost\\pcamerica")
        g_layout.addWidget(self.combo_server, 0, 1)

        self.btn_discover_servers = QPushButton("🔍 Discover Instances")
        self.btn_discover_servers.setProperty("class", "btnSecondary")
        self.btn_discover_servers.clicked.connect(self.discover_instances)
        g_layout.addWidget(self.btn_discover_servers, 0, 2)

        g_layout.addWidget(QLabel("Database Name:"), 1, 0)
        self.combo_database = QComboBox()
        self.combo_database.setEditable(True)
        self.combo_database.setPlaceholderText("e.g. cresqlvick")
        g_layout.addWidget(self.combo_database, 1, 1)

        self.btn_list_dbs = QPushButton("📋 Fetch Databases")
        self.btn_list_dbs.setProperty("class", "btnSecondary")
        self.btn_list_dbs.clicked.connect(self.fetch_databases_list)
        g_layout.addWidget(self.btn_list_dbs, 1, 2)

        g_layout.addWidget(QLabel("Authentication Mode:"), 2, 0)
        auth_hbox = QHBoxLayout()
        self.radio_auth_win = QRadioButton("🪟 Windows Authentication (Trusted Connection)")
        self.radio_auth_sql = QRadioButton("🔑 SQL Server Authentication (sa / password)")
        self.radio_auth_win.setChecked(True)
        self.radio_auth_win.toggled.connect(self.toggle_auth_fields)
        auth_hbox.addWidget(self.radio_auth_win)
        auth_hbox.addWidget(self.radio_auth_sql)
        auth_hbox.addStretch()
        g_layout.addLayout(auth_hbox, 2, 1, 1, 2)

        self.lbl_user = QLabel("SQL Username:")
        self.txt_user = QLineEdit()
        self.txt_user.setPlaceholderText("sa")
        g_layout.addWidget(self.lbl_user, 3, 0)
        g_layout.addWidget(self.txt_user, 3, 1)

        self.lbl_pwd = QLabel("SQL Password:")
        pwd_hbox = QHBoxLayout()
        self.txt_pwd = QLineEdit()
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

        grp_details = QGroupBox("Discovered Merchants and Stores in dbo.Setup")
        det_layout = QVBoxLayout(grp_details)
        det_layout.setContentsMargins(12, 14, 12, 12)

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
    # View 3: Email and SMTP Dispatch
    # -----------------------------------------------------------------------
    def setup_email_view(self):
        layout = QVBoxLayout(self.view_email)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        grp_smtp = QGroupBox("SMTP Outgoing Mail Server Configuration")
        s_layout = QGridLayout(grp_smtp)
        s_layout.setSpacing(10)
        s_layout.setContentsMargins(14, 16, 14, 14)

        s_layout.addWidget(QLabel("SMTP Host:"), 0, 0)
        self.txt_smtp_host = QLineEdit("smtp.gmail.com")
        s_layout.addWidget(self.txt_smtp_host, 0, 1)

        s_layout.addWidget(QLabel("SMTP Port:"), 0, 2)
        self.txt_smtp_port = QLineEdit("587")
        self.txt_smtp_port.setFixedWidth(80)
        s_layout.addWidget(self.txt_smtp_port, 0, 3)

        s_layout.addWidget(QLabel("SMTP Username / Email:"), 1, 0)
        self.txt_smtp_user = QLineEdit("harshilp.job10@gmail.com")
        self.txt_smtp_user.setPlaceholderText("harshilp.job10@gmail.com")
        s_layout.addWidget(self.txt_smtp_user, 1, 1, 1, 3)

        s_layout.addWidget(QLabel("Google App Password:"), 2, 0)
        pwd_box = QHBoxLayout()
        self.txt_smtp_pwd = QLineEdit("ultb bstt ebjf adrr")
        self.txt_smtp_pwd.setEchoMode(QLineEdit.EchoMode.Password)
        self.txt_smtp_pwd.setPlaceholderText("16-character Google App Password")
        self.btn_toggle_smtp_pwd = QPushButton("👁️")
        self.btn_toggle_smtp_pwd.setProperty("class", "btnSecondary")
        self.btn_toggle_smtp_pwd.setFixedWidth(36)
        self.btn_toggle_smtp_pwd.clicked.connect(lambda: self.toggle_echo(self.txt_smtp_pwd, self.btn_toggle_smtp_pwd))
        pwd_box.addWidget(self.txt_smtp_pwd)
        pwd_box.addWidget(self.btn_toggle_smtp_pwd)
        s_layout.addLayout(pwd_box, 2, 1, 1, 3)

        s_layout.addWidget(QLabel("From Header:"), 3, 0)
        self.txt_smtp_from = QLineEdit("Daily Reports <harshilp.job10@gmail.com>")
        self.txt_smtp_from.setPlaceholderText("Daily Reports <harshilp.job10@gmail.com>")
        s_layout.addWidget(self.txt_smtp_from, 3, 1, 1, 3)

        self.cb_smtp_tls = QCheckBox("Enable STARTTLS (Required for Gmail port 587)")
        self.cb_smtp_tls.setChecked(True)
        s_layout.addWidget(self.cb_smtp_tls, 4, 1, 1, 3)

        layout.addWidget(grp_smtp)

        grp_recip = QGroupBox("Report Delivery and Recipients")
        r_layout = QGridLayout(grp_recip)
        r_layout.setSpacing(10)
        r_layout.setContentsMargins(14, 16, 14, 14)

        r_layout.addWidget(QLabel("Report Recipients (comma-separated):"), 0, 0)
        self.txt_recipients = QLineEdit()
        self.txt_recipients.setPlaceholderText("storeowner@example.com, accountant@example.com")
        r_layout.addWidget(self.txt_recipients, 0, 1)

        r_layout.addWidget(QLabel("SMS Gateway Recipients (optional):"), 1, 0)
        self.txt_sms_recipients = QLineEdit()
        self.txt_sms_recipients.setPlaceholderText("5551234567@vtext.com (optional)")
        r_layout.addWidget(self.txt_sms_recipients, 1, 1)

        self.cb_dry_run = QCheckBox("🛡️ Dry-Run Mode (Generate and save files locally, do NOT transmit real emails)")
        r_layout.addWidget(self.cb_dry_run, 2, 1)

        act_box = QHBoxLayout()
        self.btn_test_email = QPushButton("✉️ Send Connection Test Email")
        self.btn_test_email.setProperty("class", "btnSecondary")
        self.btn_test_email.clicked.connect(self.send_test_email)
        act_box.addWidget(self.btn_test_email)

        self.btn_quick_dispatch = QPushButton("🚀 Generate and Send Full Sales Report Now")
        self.btn_quick_dispatch.setStyleSheet("""
            QPushButton {
                background-color: #059669;
                color: #ffffff !important;
                font-weight: 700;
                font-size: 13px;
                padding: 8px 18px;
                border-radius: 6px;
                border: none;
            }
            QPushButton:hover {
                background-color: #047857;
            }
        """)
        self.btn_quick_dispatch.clicked.connect(self.generate_and_dispatch_full_report)
        act_box.addWidget(self.btn_quick_dispatch)

        act_box.addStretch()
        r_layout.addLayout(act_box, 3, 1)

        layout.addWidget(grp_recip)
        layout.addStretch()

    # -----------------------------------------------------------------------
    # View 4: Settings and Automated Scheduling
    # -----------------------------------------------------------------------
    def setup_settings_view(self):
        layout = QVBoxLayout(self.view_settings)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        # 1. GitHub Remote Updates Box
        grp_updates = QGroupBox("🔄 GitHub Remote Updates and Auto-Updater")
        u_layout = QGridLayout(grp_updates)
        u_layout.setSpacing(10)
        u_layout.setContentsMargins(14, 16, 14, 14)

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

        lbl_up_info = QLabel("Updates automatically replace the executable without overwriting your local database connection or settings.")
        lbl_up_info.setStyleSheet("color: #64748b; font-size: 12px;")
        u_layout.addWidget(lbl_up_info, 2, 0, 1, 3)

        layout.addWidget(grp_updates)

        # 2. Automated Schedule Box
        grp_sched = QGroupBox("⏰ Automated Daily Report Scheduling")
        sc_layout = QGridLayout(grp_sched)
        sc_layout.setSpacing(10)
        sc_layout.setContentsMargins(14, 16, 14, 14)

        sc_layout.addWidget(QLabel("Daily Dispatch Time:"), 0, 0)
        self.time_schedule = QTimeEdit()
        self.time_schedule.setDisplayFormat("hh:mm AP")
        self.time_schedule.setTime(QTime(7, 0))
        sc_layout.addWidget(self.time_schedule, 0, 1)

        self.cb_schedule_enabled = QCheckBox("Enable Windows Automated Task Dispatch")
        self.cb_schedule_enabled.setChecked(True)
        sc_layout.addWidget(self.cb_schedule_enabled, 0, 2)

        lbl_sc_info = QLabel("Configure the daily morning time when automated sales reports are processed and emailed:")
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
        grp_auth = QGroupBox("🔐 Team Master Password and Security Gate")
        a_layout = QVBoxLayout(grp_auth)
        a_layout.setSpacing(8)
        a_layout.setContentsMargins(14, 16, 14, 14)

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
        grp_dirs = QGroupBox("Directories and Storage")
        d_layout = QGridLayout(grp_dirs)
        d_layout.setSpacing(10)
        d_layout.setContentsMargins(14, 16, 14, 14)

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
            self.show_toast("Update Available", f"Version v{info.latest_version} is available!", "info")
            self.log(f"Update available: v{info.latest_version} (Current: v{updater.CURRENT_VERSION})", "WARN")

            if info.is_forced:
                self.show_toast("Mandatory Update", f"Installing required version v{info.latest_version}...", "warning")
                self.execute_update_process()
        else:
            self.frame_update_banner.setVisible(False)
            if not getattr(self, "update_check_silent", True):
                self.show_toast("Up to Date", f"Specialized Reporting is up to date (v{updater.CURRENT_VERSION}).", "success")

    def on_update_check_error(self, err: str):
        self.progress_bar.setVisible(False)
        if not getattr(self, "update_check_silent", True):
            self.show_toast("Update Check Notice", str(err), "warning")

    def execute_update_process(self):
        if not self.pending_update_info or not self.pending_update_info.download_url:
            self.show_toast("Update Error", "No valid update download URL found.", "error")
            return

        info = self.pending_update_info
        target_path = BASE_DIR / "Specialized_Reporting.exe.new"

        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.show_toast("Downloading Update", f"Downloading v{info.latest_version}...", "info")
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
        self.show_toast("Update Ready", "Restarting application to apply update...", "success")
        self.log("Download complete! Applying update and restarting...", "SUCCESS")
        
        QTimer.singleShot(1000, lambda: updater.apply_update_and_restart(BASE_DIR, "Specialized_Reporting.exe"))

    def on_download_error(self, err: str):
        self.progress_bar.setVisible(False)
        self.show_toast("Download Failed", str(err), "error")
        self.log(f"Download failed: {err}", "ERROR")

    def register_windows_task(self):
        time_str = self.time_schedule.time().toString("HH:mm")
        exe_path = Path(sys.executable).resolve() if getattr(sys, "frozen", False) else (BASE_DIR / "Specialized_Reporting.exe")

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
                self.show_toast("Task Registered", f"Reports scheduled daily at {self.time_schedule.time().toString('hh:mm AP')}!", "success")
                self.log(f"Windows Task Scheduler configured for {self.time_schedule.time().toString('hh:mm AP')}.", "SUCCESS")
            else:
                self.show_toast("Task Notice", res.stderr.strip() or res.stdout.strip(), "warning")
        except Exception as e:
            self.show_toast("Scheduler Error", str(e), "error")

    def remove_windows_task(self):
        cmd = ["schtasks", "/delete", "/tn", "pcAmerica_Daily_Sales_Report", "/f"]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True)
            self.show_toast("Task Removed", "Windows scheduled daily report task removed.", "info")
            self.log("Removed pcAmerica scheduled task.", "INFO")
        except Exception as e:
            self.show_toast("Error", str(e), "error")

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

        db = cfg.get("SQL_DATABASE", "")
        idx_db = self.combo_database.findText(db)
        if idx_db >= 0:
            self.combo_database.setCurrentIndex(idx_db)
        else:
            self.combo_database.setEditText(db)

        auth = cfg.get("SQL_AUTH", "windows").lower()
        if auth in ("sql", "sql server", "sql server authentication"):
            self.radio_auth_sql.setChecked(True)
        else:
            self.radio_auth_win.setChecked(True)
        self.toggle_auth_fields()

        self.txt_user.setText(cfg.get("SQL_USER", ""))
        self.txt_pwd.setText(cfg.get("SQL_PASSWORD", ""))

        self.txt_smtp_host.setText(cfg.get("SMTP_HOST") or "smtp.gmail.com")
        self.txt_smtp_port.setText(cfg.get("SMTP_PORT") or "587")
        self.txt_smtp_user.setText(cfg.get("SMTP_USER") or "harshilp.job10@gmail.com")
        self.txt_smtp_pwd.setText(cfg.get("SMTP_PASSWORD") or "ultb bstt ebjf adrr")
        self.txt_smtp_from.setText(cfg.get("SMTP_FROM") or "Daily Reports <harshilp.job10@gmail.com>")
        self.cb_smtp_tls.setChecked(cfg.get("SMTP_USE_TLS", "true").lower() in ("true", "1", "yes"))

        self.txt_recipients.setText(cfg.get("REPORT_RECIPIENT") or "harshil@jdgurus.com")
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

        if srv and db:
            self.lbl_header_db_badge.setText(f"{srv} / {db}")

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
            self.show_toast("Access Denied", "Please unlock Team Admin Mode to save configuration.", "warning")
            return

        try:
            cfg = self.collect_ui_settings()
            save_app_env(cfg)
            self.cfg = cfg
            srv = cfg.get("SQL_SERVER", "")
            db = cfg.get("SQL_DATABASE", "")
            if srv and db:
                self.lbl_header_db_badge.setText(f"{srv} / {db}")
            self.show_toast("Configuration Saved", "Settings synchronized to config.env successfully!", "success")
            self.log("Configuration saved to config.env.", "SUCCESS")
        except Exception as e:
            self.show_toast("Save Error", str(e), "error")
            self.log(f"Failed saving configuration: {e}", "ERROR")

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
        self.show_toast("Discovery Complete", f"Found {len(instances)} SQL Server instance(s).", "info")
        self.log(f"Discovered {len(instances)} instance(s): {', '.join(instances)}", "SUCCESS")

    def fetch_databases_list(self):
        server = self.combo_server.currentText().strip()
        if not server:
            self.show_toast("Instance Required", "Please enter or select a SQL Server Instance.", "warning")
            return
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
                self.show_toast("Databases Fetched", f"Found {len(dbs)} database(s) on server.", "success")
                self.log(f"Catalog fetched: {len(dbs)} database(s) found.", "SUCCESS")
        except Exception as e:
            self.show_toast("Database Fetch Error", str(e), "error")
            self.log(f"Failed fetching databases: {e}", "ERROR")

    def test_db_connection(self):
        server = self.combo_server.currentText().strip()
        database = self.combo_database.currentText().strip()
        if not server or not database:
            self.show_toast("Parameters Missing", "Please enter both SQL Server Instance and Database Name.", "warning")
            return
        auth = "sql" if self.radio_auth_sql.isChecked() else "windows"
        user = self.txt_user.text().strip()
        pwd = self.txt_pwd.text().strip()

        self.log(f"Testing connection to {server}/{database} ({auth})...")
        ok, msg = report_db.test_connection(server, database, auth, user, pwd)
        if ok:
            self.lbl_side_db_chip.setText(f"🟢 SQL: Connected")
            self.lbl_side_db_chip.setStyleSheet("color: #10b981; font-weight: bold; font-size: 11px;")
            self.lbl_header_db_badge.setText(f"{server} / {database}")
            self.show_toast("Connection Successful", f"Connected to {database}!", "success")
            self.log(f"Database connection verified: {msg}", "SUCCESS")
        else:
            self.lbl_side_db_chip.setText("🔴 SQL: Disconnected")
            self.lbl_side_db_chip.setStyleSheet("color: #ef4444; font-weight: bold; font-size: 11px;")
            self.show_toast("Connection Failed", msg, "error")
            self.log(f"Database connection failed: {msg}", "ERROR")

    def auto_connect_on_startup(self):
        server = self.combo_server.currentText().strip()
        database = self.combo_database.currentText().strip()
        if not server:
            return
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
        if not server or not database:
            self.show_toast("Parameters Missing", "Please enter SQL Server Instance and Database Name.", "warning")
            return
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
        self.lbl_side_db_chip.setText(f"🟢 SQL: Connected")
        self.lbl_side_db_chip.setStyleSheet("color: #10b981; font-weight: bold; font-size: 11px;")
        self.lbl_side_store_chip.setText(f"🏪 Stores: {len(stores)} found")
        self.lbl_header_db_badge.setText(f"{server} / {database}")

        if latest_s:
            qd = QDate.fromString(latest_s, "yyyy-MM-dd")
            if qd.isValid() and self.combo_date_preset.currentText() == "Latest Date in DB":
                self.dt_start.setDate(qd)
                self.dt_end.setDate(qd)

    def on_server_fetch_error(self, err: str):
        self.progress_bar.setVisible(False)
        self.lbl_side_db_chip.setText("🔴 SQL: Error")
        self.lbl_side_db_chip.setStyleSheet("color: #ef4444; font-weight: bold; font-size: 11px;")
        self.show_toast("Auto-Fetch Notice", str(err), "error")
        self.log(f"Auto-fetch failure: {err}", "ERROR")

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
            self.show_toast("Incomplete SMTP Config", str(err), "warning")
            return

        recipients = [r.strip() for r in re.split(r"[,;\s]+", self.txt_recipients.text().strip()) if r.strip() and "@" in r]
        if not recipients:
            self.show_toast("Recipient Required", "Please enter at least one recipient email address.", "warning")
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
            self.show_toast("Test Email Sent", f"Sent successfully to {len(recipients)} recipient(s)!", "success")
            self.log("SMTP verification email sent successfully!", "SUCCESS")
        except Exception as e:
            self.show_toast("Email Dispatch Failed", str(e), "error")
            self.log(f"SMTP dispatch failure: {e}", "ERROR")

    # -----------------------------------------------------------------------
    # Report Generation and Live Explorer
    # -----------------------------------------------------------------------
    def generate_and_preview_report(self):
        server = self.combo_server.currentText().strip()
        database = self.combo_database.currentText().strip()
        if not server or not database:
            self.show_toast("Configuration Required", "Please configure SQL Server and Database in the SQL Server tab.", "warning")
            return
        auth = "sql" if self.radio_auth_sql.isChecked() else "windows"
        user = self.txt_user.text().strip()
        pwd = self.txt_pwd.text().strip()

        st_id = self.combo_run_store.currentData()
        start_d = _to_py_date(self.dt_start.date())
        end_d = _to_py_date(self.dt_end.date())

        if start_d > end_d:
            self.show_toast("Invalid Range", "Start Date cannot be after End Date.", "warning")
            return

        active_sections = self.get_selected_sections()
        if not active_sections:
            self.show_toast("No Modules Selected", "Please select at least one module in Module Filter.", "warning")
            return

        attach_xlsx = self.cb_attach_xlsx.isChecked()
        attach_csv = self.cb_attach_csv.isChecked()

        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)
        self.btn_generate_preview.setEnabled(False)
        self.show_toast("Generating Report", f"Querying sales data ({start_d.strftime('%m/%d/%Y')} to {end_d.strftime('%m/%d/%Y')})...", "info")

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

        if bundles:
            b0 = bundles[0]
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

        self.show_toast("Report Generated", f"Generated {len(bundles)} report(s). Total: ${float(metrics.get('gross_sales', 0)):,.2f}", "success")
        self.log("Report rendering complete.", "SUCCESS")

        if getattr(self, "auto_dispatch_after_generation", False):
            self.auto_dispatch_after_generation = False
            QTimer.singleShot(600, self.send_email_now)

    def generate_and_dispatch_full_report(self):
        try:
            self.nav_list.setCurrentRow(0)
            self.show_toast("Generating Report", "Extracting store sales data to send report...", "info")
            self.auto_dispatch_after_generation = True
            self.generate_and_preview_report()
        except Exception as e:
            self.show_toast("Dispatch Error", str(e), "error")
            self.log(f"Dispatch error: {e}", "ERROR")

    def on_report_error(self, err: str):
        self.progress_bar.setVisible(False)
        self.btn_generate_preview.setEnabled(True)
        self.show_toast("Report Error", str(err), "error")
        self.log(f"Report generation error: {err}", "ERROR")

    def send_email_now(self):
        if not self.latest_bundles or not self.latest_generated_files:
            self.show_toast("Generate First", "Please click 'Generate Report' before dispatching emails.", "info")
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
            self.show_toast("Incomplete SMTP", str(err), "warning")
            return

        recipients = [r.strip() for r in re.split(r"[,;\s]+", self.txt_recipients.text().strip()) if r.strip() and "@" in r]
        if not recipients:
            self.show_toast("No Recipients", "Please enter at least one recipient email address in Email Dispatch.", "warning")
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
        self.show_toast("Emails Dispatched", f"Successfully sent {count} store report email(s)!", "success")
        self.log(f"Dispatched {count} report email(s) successfully.", "SUCCESS")

    def on_email_sent_error(self, err: str):
        self.progress_bar.setVisible(False)
        self.btn_send_email_now.setEnabled(True)
        self.show_toast("Email Error", str(err), "error")
        self.log(f"Email dispatch error: {err}", "ERROR")

    def open_output_folder(self):
        out_path = Path(self.txt_output_dir.text().strip() or OUTPUT_ROOT)
        out_path.mkdir(parents=True, exist_ok=True)
        try:
            os.startfile(str(out_path))
        except Exception as e:
            self.show_toast("Folder Notice", str(e), "warning")


# ---------------------------------------------------------------------------
# App Entry Point (Dual-Mode: GUI or Background Scheduled Runner)
# ---------------------------------------------------------------------------

def main():
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
