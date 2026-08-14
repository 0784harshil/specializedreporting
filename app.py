"""pcAmerica CRE — Sales & Operations Reporting Studio (Web UI)

Interactive browser-based studio for pcAmerica CRE SQL Server database:
  - Cryptographic Salted SHA-256 Team Password Protection
  - Dual Authentication: Windows Authentication & SQL Server Authentication
  - Server auto-discovery and auto-fetch from dbo.Setup
  - Dynamic module / section filtering (Key Metrics, Departments, Fixed Tax, Top Items, Hourly, Payments, Employees, Voids, Price Changes, Deletes, Transactions)
  - Live HTML email preview, Excel/CSV downloads, and SMTP email dispatch
  - Configuration persistence to config.env / .env
"""

from __future__ import annotations

import datetime as _dt
import os
import re
from pathlib import Path
from typing import Optional

import pandas as pd
import streamlit as st
import streamlit.components.v1 as components
from dotenv import load_dotenv

import auth_guard
import report_db
import report_mailer
import report_render
from report_render import AVAILABLE_SECTIONS, DEFAULT_SECTIONS, ReportBundle

# ---------------------------------------------------------------------------
# Setup & Styling
# ---------------------------------------------------------------------------

st.set_page_config(
    page_title="pcAmerica CRE Reporting Studio",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

BASE_DIR = Path(__file__).resolve().parent
CONFIG_FILE = BASE_DIR / "config.env"
DOTENV_FILE = BASE_DIR / ".env"
OUTPUT_ROOT = BASE_DIR / "daily_reports"


def load_config_dict() -> dict[str, str]:
    if CONFIG_FILE.exists():
        load_dotenv(CONFIG_FILE, override=True)
    elif DOTENV_FILE.exists():
        load_dotenv(DOTENV_FILE, override=True)

    return {
        "SQL_SERVER": os.getenv("SQL_SERVER", r"Harshil\pcamerica"),
        "SQL_DATABASE": os.getenv("SQL_DATABASE", "cresqlvick"),
        "SQL_AUTH": os.getenv("SQL_AUTH", "windows").lower(),
        "SQL_USER": os.getenv("SQL_USER", "sa"),
        "SQL_PASSWORD": os.getenv("SQL_PASSWORD", "pcAmer1ca"),
        "SMTP_HOST": os.getenv("SMTP_HOST", "smtp.gmail.com"),
        "SMTP_PORT": os.getenv("SMTP_PORT", "587"),
        "SMTP_USER": os.getenv("SMTP_USER", "harshilp.job10@gmail.com"),
        "SMTP_PASSWORD": os.getenv("SMTP_PASSWORD", ""),
        "SMTP_FROM": os.getenv("SMTP_FROM", "Daily Reports <harshilp.job10@gmail.com>"),
        "SMTP_USE_TLS": os.getenv("SMTP_USE_TLS", "true"),
        "REPORT_RECIPIENT": os.getenv("REPORT_RECIPIENT", "harshil@jdgurus.com"),
        "SMS_RECIPIENTS": os.getenv("SMS_RECIPIENTS", ""),
        "REPORT_DATE_MODE": os.getenv("REPORT_DATE_MODE", "yesterday"),
        "DRY_RUN": os.getenv("DRY_RUN", "false"),
        "REPORT_SECTIONS": os.getenv("REPORT_SECTIONS", ",".join(DEFAULT_SECTIONS)),
        "ATTACH_XLSX": os.getenv("ATTACH_XLSX", "true"),
        "ATTACH_CSV": os.getenv("ATTACH_CSV", "true"),
    }


def save_config_dict(cfg: dict[str, str]) -> None:
    lines = [
        "# ===================================================================",
        "# pcAmerica CRE Daily Sales & Operations Reporting Configuration",
        f"# Updated: {_dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "# ===================================================================",
        "",
        "# --- SQL Server Connection ---",
        f"SQL_SERVER={cfg.get('SQL_SERVER', '')}",
        f"SQL_DATABASE={cfg.get('SQL_DATABASE', 'cresqlvick')}",
        f"SQL_AUTH={cfg.get('SQL_AUTH', 'windows')}",
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
    ]
    content = "\n".join(lines)
    CONFIG_FILE.write_text(content, encoding="utf-8")
    DOTENV_FILE.write_text(content, encoding="utf-8")
    load_dotenv(CONFIG_FILE, override=True)


if "cfg" not in st.session_state:
    st.session_state.cfg = load_config_dict()

cfg = st.session_state.cfg

if "is_admin_unlocked" not in st.session_state:
    st.session_state.is_admin_unlocked = False

# ---------------------------------------------------------------------------
# Custom CSS for Professional Dashboard Look
# ---------------------------------------------------------------------------

st.markdown("""
<style>
    .reportview-container .main .block-container {
        padding-top: 1.5rem;
        padding-bottom: 2rem;
    }
    .header-banner {
        background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
        color: white;
        padding: 18px 24px;
        border-radius: 10px;
        margin-bottom: 20px;
        border-left: 5px solid #2563eb;
    }
    .header-banner h1 {
        margin: 0;
        color: #ffffff;
        font-size: 24px;
        font-weight: 700;
    }
    .header-banner p {
        margin: 4px 0 0 0;
        color: #94a3b8;
        font-size: 13px;
    }
    .stTabs [data-baseweb="tab-list"] {
        gap: 8px;
    }
    .stTabs [data-baseweb="tab"] {
        height: 44px;
        white-space: pre-wrap;
        background-color: #f1f5f9;
        border-radius: 6px 6px 0px 0px;
        gap: 4px;
        padding-top: 10px;
        padding-bottom: 10px;
        font-weight: 600;
    }
    .stTabs [aria-selected="true"] {
        background-color: #2563eb !important;
        color: #ffffff !important;
    }
</style>
""", unsafe_allow_html=True)

# ---------------------------------------------------------------------------
# Header Banner
# ---------------------------------------------------------------------------

lock_badge = "🔓 <b>Team Mode Active</b>" if st.session_state.is_admin_unlocked else "🔒 <b>Restricted Merchant Mode</b>"
st.markdown(f"""
<div class="header-banner">
    <h1>📊 pcAmerica CRE — Sales & Operations Reporting Studio</h1>
    <p>Automated Multi-Module Reporting • SQL Server Auto-Discovery & Auto-Fetch • {lock_badge}</p>
</div>
""", unsafe_allow_html=True)

# ---------------------------------------------------------------------------
# Sidebar: Security Gate & Server Configuration
# ---------------------------------------------------------------------------

with st.sidebar:
    st.header("🔐 Team Security Gate")
    if not st.session_state.is_admin_unlocked:
        st.info("🔒 Settings are locked. Enter the IT/Support Team Password to modify server and email settings.")
        login_pwd = st.text_input("Team Password", type="password", placeholder="Enter Team Password")
        if st.button("🔓 Unlock Team Mode", use_container_width=True, type="primary"):
            if auth_guard.verify_team_password(login_pwd):
                st.session_state.is_admin_unlocked = True
                st.success("✅ Team Access Granted!")
                st.rerun()
            else:
                st.error("❌ Incorrect Password.")
    else:
        col_u1, col_u2 = st.columns([3, 2])
        col_u1.success("🔓 Unlocked")
        if col_u2.button("🔒 Lock", use_container_width=True):
            st.session_state.is_admin_unlocked = False
            st.rerun()

    st.markdown("---")
    st.header("⚙️ Server & Connection")

    # Instance Discovery
    instances = report_db.discover_local_sql_instances()
    saved_srv = cfg.get("SQL_SERVER", r"Harshil\pcamerica")
    
    srv_options = list(instances)
    if saved_srv not in srv_options:
        srv_options.insert(0, saved_srv)
    srv_options.append("Other (Enter Manually)...")
    
    default_srv_idx = srv_options.index(saved_srv) if saved_srv in srv_options else 0
    selected_srv = st.selectbox("SQL Server Instance", srv_options, index=default_srv_idx, disabled=not st.session_state.is_admin_unlocked)
    
    if selected_srv == "Other (Enter Manually)...":
        server_val = st.text_input("Server Name", value=saved_srv, disabled=not st.session_state.is_admin_unlocked)
    else:
        server_val = selected_srv

    db_val = st.text_input("Database Name", value=cfg.get("SQL_DATABASE", "cresqlvick"), disabled=not st.session_state.is_admin_unlocked)

    auth_options = ["Windows Authentication (Trusted)", "SQL Server Authentication"]
    auth_default = 1 if cfg.get("SQL_AUTH") in ("sql", "sql server") else 0
    selected_auth = st.radio("Authentication Method", auth_options, index=auth_default, disabled=not st.session_state.is_admin_unlocked)
    auth_val = "sql" if selected_auth == "SQL Server Authentication" else "windows"

    if auth_val == "sql":
        user_val = st.text_input("SQL Username", value=cfg.get("SQL_USER", "sa"), disabled=not st.session_state.is_admin_unlocked)
        pwd_val = st.text_input("SQL Password", value=cfg.get("SQL_PASSWORD", "pcAmer1ca"), type="password", disabled=not st.session_state.is_admin_unlocked)
    else:
        user_val = ""
        pwd_val = ""

    col_btn1, col_btn2 = st.columns(2)
    with col_btn1:
        if st.button("⚡ Test DB", use_container_width=True):
            ok, msg = report_db.test_connection(server_val, db_val, auth_val, user_val, pwd_val)
            if ok:
                st.success(f"✅ {msg}")
            else:
                st.error(f"❌ {msg}")
    
    with col_btn2:
        fetch_db_btn = st.button("🔄 Auto-Fetch", use_container_width=True)

    st.markdown("---")
    st.header("📧 Email & SMTP Settings")

    smtp_host = st.text_input("SMTP Host", value=cfg.get("SMTP_HOST", "smtp.gmail.com"), disabled=not st.session_state.is_admin_unlocked)
    smtp_port = st.text_input("SMTP Port", value=cfg.get("SMTP_PORT", "587"), disabled=not st.session_state.is_admin_unlocked)
    smtp_user = st.text_input("SMTP User (Gmail)", value=cfg.get("SMTP_USER", "harshilp.job10@gmail.com"), disabled=not st.session_state.is_admin_unlocked)
    smtp_pwd = st.text_input("Google App Password", value=cfg.get("SMTP_PASSWORD", ""), type="password", disabled=not st.session_state.is_admin_unlocked)
    smtp_from = st.text_input("From Header", value=cfg.get("SMTP_FROM", "Daily Reports <harshilp.job10@gmail.com>"), disabled=not st.session_state.is_admin_unlocked)
    smtp_tls = st.checkbox("Enable STARTTLS", value=cfg.get("SMTP_USE_TLS", "true").lower() in ("true", "1", "yes"), disabled=not st.session_state.is_admin_unlocked)

    recipients_val = st.text_input("Report Recipients (comma-sep)", value=cfg.get("REPORT_RECIPIENT", "harshil@jdgurus.com"), disabled=not st.session_state.is_admin_unlocked)
    sms_val = st.text_input("SMS Gateway Recipients (optional)", value=cfg.get("SMS_RECIPIENTS", ""), disabled=not st.session_state.is_admin_unlocked)
    dry_run_val = st.checkbox("🛡️ Dry-Run Mode (No real emails)", value=cfg.get("DRY_RUN", "false").lower() in ("true", "1", "yes"), disabled=not st.session_state.is_admin_unlocked)

    if st.button("✉️ Send Test Email", use_container_width=True):
        smtp_cfg = report_mailer.SmtpConfig(
            host=smtp_host.strip(),
            port=int(smtp_port.strip() or 587),
            user=smtp_user.strip(),
            password=smtp_pwd.strip(),
            from_addr=smtp_from.strip(),
            use_tls=smtp_tls,
        )
        err = smtp_cfg.validate()
        if err:
            st.error(f"SMTP Error: {err}")
        else:
            recips = [r.strip() for r in re.split(r"[,;\s]+", recipients_val.strip()) if r.strip() and "@" in r]
            if not recips:
                st.error("Please provide at least one valid recipient address.")
            else:
                job = report_mailer.EmailJob(
                    to=recips,
                    cc=[], bcc=[],
                    subject="Verification Test — pcAmerica CRE Reporting Studio",
                    html_body="<h3>✅ SMTP Connected Successfully</h3><p>Your pcAmerica CRE Reporting Studio can send emails.</p>",
                    attachments=[],
                )
                try:
                    report_mailer.send(smtp_cfg, job)
                    st.success(f"✅ Test email sent to: {', '.join(recips)}")
                except Exception as e:
                    st.error(f"Failed to send email: {e}")

    st.markdown("---")
    if st.button("💾 Save All Settings to .env", use_container_width=True, type="primary", disabled=not st.session_state.is_admin_unlocked):
        active_secs = st.session_state.get("selected_sections", set(DEFAULT_SECTIONS))
        new_cfg = {
            "SQL_SERVER": server_val,
            "SQL_DATABASE": db_val,
            "SQL_AUTH": auth_val,
            "SQL_USER": user_val,
            "SQL_PASSWORD": pwd_val,
            "SMTP_HOST": smtp_host,
            "SMTP_PORT": smtp_port,
            "SMTP_USER": smtp_user,
            "SMTP_PASSWORD": smtp_pwd,
            "SMTP_FROM": smtp_from,
            "SMTP_USE_TLS": "true" if smtp_tls else "false",
            "REPORT_RECIPIENT": recipients_val,
            "SMS_RECIPIENTS": sms_val,
            "REPORT_DATE_MODE": cfg.get("REPORT_DATE_MODE", "yesterday"),
            "DRY_RUN": "true" if dry_run_val else "false",
            "REPORT_SECTIONS": ",".join(sorted(active_secs)),
            "ATTACH_XLSX": "true" if st.session_state.get("attach_xlsx", True) else "false",
            "ATTACH_CSV": "true" if st.session_state.get("attach_csv", True) else "false",
        }
        save_config_dict(new_cfg)
        st.session_state.cfg = new_cfg
        st.success("✅ Configuration saved to config.env and .env!")

# ---------------------------------------------------------------------------
# Server Auto-Fetch State
# ---------------------------------------------------------------------------

if "server_summary" not in st.session_state or fetch_db_btn:
    try:
        with report_db.open_connection(server_val, db_val, auth_val, user_val, pwd_val) as conn:
            st.session_state.server_summary = report_db.fetch_server_summary(conn)
    except Exception as e:
        st.session_state.server_summary = {"stores": [], "latest_sales_date": None, "latest_clock_date": None}

summary = st.session_state.server_summary
stores_list = summary.get("stores", [])
latest_sales_d = summary.get("latest_sales_date")
latest_clock_d = summary.get("latest_clock_date")

# ---------------------------------------------------------------------------
# Main Tabs Layout
# ---------------------------------------------------------------------------

tab_runner, tab_modules, tab_stores, tab_security = st.tabs([
    "🚀 Run & Live Preview",
    "🧩 Report Modules & Sections",
    "🏪 Discovered Stores & DB Info",
    "🔐 Security & Password Manager",
])

# ---------------------------------------------------------------------------
# Tab 1: Run & Live Preview
# ---------------------------------------------------------------------------

with tab_runner:
    st.subheader("Generate & Email Sales Reports")

    col_store, col_preset, col_dates = st.columns([2, 2, 3])

    with col_store:
        store_options = {"All Stores": None}
        for st_item in stores_list:
            store_options[f"Store {st_item['store_id']} — {st_item['store_name']}"] = st_item["store_id"]
        selected_store_label = st.selectbox("Select Store", list(store_options.keys()))
        selected_store_id = store_options[selected_store_label]

    with col_preset:
        preset_choice = st.selectbox(
            "Date Preset",
            ["Latest Sales in DB", "Yesterday", "Today", "Last 7 Days", "Custom Range"]
        )

    today = _dt.date.today()
    if preset_choice == "Latest Sales in DB" and latest_sales_d:
        default_start = _dt.date.fromisoformat(latest_sales_d)
        default_end = default_start
    elif preset_choice == "Yesterday":
        default_start = today - _dt.timedelta(days=1)
        default_end = default_start
    elif preset_choice == "Today":
        default_start = today
        default_end = today
    elif preset_choice == "Last 7 Days":
        default_start = today - _dt.timedelta(days=7)
        default_end = today
    else:
        default_start = today - _dt.timedelta(days=1)
        default_end = today

    with col_dates:
        col_s, col_e = st.columns(2)
        with col_s:
            start_date = st.date_input("Start Date", value=default_start)
        with col_e:
            end_date = st.date_input("End Date", value=default_end)

    col_act1, col_act2, col_act3 = st.columns([2, 2, 3])
    with col_act1:
        run_btn = st.button("🚀 Generate & Preview Report", use_container_width=True, type="primary")
    with col_act2:
        send_btn = st.button("✉️ Send Email Report Now", use_container_width=True)
    with col_act3:
        if latest_sales_d:
            st.info(f"📅 **Latest SQL Sales:** `{latest_sales_d}` | **TimeClock:** `{latest_clock_d or 'N/A'}`")

    active_sections = st.session_state.get("selected_sections", set(DEFAULT_SECTIONS))
    attach_xlsx = st.session_state.get("attach_xlsx", True)
    attach_csv = st.session_state.get("attach_csv", True)

    if run_btn or "last_bundle" in st.session_state:
        if run_btn:
            if start_date > end_date:
                st.error("Error: Start Date cannot be after End Date.")
            else:
                with st.spinner("Fetching report data from SQL Server..."):
                    try:
                        with report_db.open_connection(server_val, db_val, auth_val, user_val, pwd_val) as conn:
                            merchants_df = report_db.fetch_merchants(conn, store_id=selected_store_id)
                            if merchants_df.empty:
                                st.warning("No store rows found in dbo.Setup.")
                            else:
                                bundles = []
                                for _, row in merchants_df.iterrows():
                                    mdict = row.to_dict()
                                    st_id = str(mdict.get("Store_ID") or "").strip()
                                    b = ReportBundle(
                                        store_id=st_id,
                                        merchant=mdict,
                                        start=start_date,
                                        end=end_date,
                                        kpis=report_db.fetch_invoice_kpis(conn, st_id, start_date, end_date),
                                        by_department=report_db.fetch_sales_by_department(conn, st_id, start_date, end_date),
                                        by_fixed_tax=report_db.fetch_sales_by_fixed_tax(conn, st_id, start_date, end_date),
                                        top_items=report_db.fetch_top_items(conn, st_id, start_date, end_date),
                                        by_hour=report_db.fetch_sales_by_hour(conn, st_id, start_date, end_date),
                                        by_payment=report_db.fetch_payment_breakdown(conn, st_id, start_date, end_date),
                                        transactions=report_db.fetch_itemized_transactions(conn, st_id, start_date, end_date),
                                        employees=report_db.fetch_employee_records(conn, st_id, start_date, end_date),
                                        audit_events=report_db.fetch_audit_events(conn, st_id, start_date, end_date),
                                    )
                                    bundles.append(b)
                                st.session_state.last_bundles = bundles
                    except Exception as e:
                        st.error(f"Error querying SQL Server: {e}")

        if "last_bundles" in st.session_state and st.session_state.last_bundles:
            bundles = st.session_state.last_bundles
            b0 = bundles[0]

            total_inv = sum(int(b.kpis.iloc[0]["invoice_count"]) for b in bundles if not b.kpis.empty)
            total_gross = sum(float(b.kpis.iloc[0]["gross_sales"]) for b in bundles if not b.kpis.empty)
            total_cash = sum(float(b.kpis.iloc[0]["cash_collected"]) for b in bundles if not b.kpis.empty)
            total_tax = sum(float(b.kpis.iloc[0]["sales_tax"]) for b in bundles if not b.kpis.empty)
            avg_ticket = (total_gross / total_inv) if total_inv else 0.0

            mcol1, mcol2, mcol3, mcol4, mcol5 = st.columns(5)
            mcol1.metric("Total Invoices", f"{total_inv:,}")
            mcol2.metric("Net Sales", f"${total_gross:,.2f}")
            mcol3.metric("Average Ticket", f"${avg_ticket:,.2f}")
            mcol4.metric("Sales Tax", f"${total_tax:,.2f}")
            mcol5.metric("Cash Collected", f"${total_cash:,.2f}")

            st.markdown("---")

            html_output = report_render.render_html(b0, active_sections=active_sections)
            
            dcol1, dcol2, dcol3 = st.columns(3)
            with dcol1:
                st.download_button(
                    "📥 Download HTML Report",
                    data=html_output.encode("utf-8"),
                    file_name=f"report_{b0.store_id}_{b0.start}.html",
                    mime="text/html",
                    use_container_width=True,
                )
            with dcol2:
                xlsx_buf = BASE_DIR / "temp_report.xlsx"
                report_render.render_xlsx(b0, str(xlsx_buf), active_sections=active_sections)
                with open(xlsx_buf, "rb") as f:
                    xlsx_data = f.read()
                if xlsx_buf.exists():
                    os.remove(xlsx_buf)
                st.download_button(
                    "📊 Download Excel (.xlsx)",
                    data=xlsx_data,
                    file_name=f"report_{b0.store_id}_{b0.start}.xlsx",
                    mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    use_container_width=True,
                )
            with dcol3:
                csv_data = b0.transactions.to_csv(index=False).encode("utf-8-sig")
                st.download_button(
                    "📄 Download Transactions CSV",
                    data=csv_data,
                    file_name=f"transactions_{b0.store_id}_{b0.start}.csv",
                    mime="text/csv",
                    use_container_width=True,
                )

            st.markdown("### 📄 Live Report Preview (Exact Email Layout)")
            components.html(html_output, height=750, scrolling=True)

    if send_btn:
        if "last_bundles" not in st.session_state or not st.session_state.last_bundles:
            st.warning("Please generate a report first before sending.")
        else:
            smtp_cfg = report_mailer.SmtpConfig(
                host=smtp_host.strip(),
                port=int(smtp_port.strip() or 587),
                user=smtp_user.strip(),
                password=smtp_pwd.strip(),
                from_addr=smtp_from.strip(),
                use_tls=smtp_tls,
            )
            err = smtp_cfg.validate()
            if err:
                st.error(f"SMTP Configuration Error: {err}")
            else:
                recips = [r.strip() for r in re.split(r"[,;\s]+", recipients_val.strip()) if r.strip() and "@" in r]
                if not recips:
                    st.error("No recipient email address provided.")
                else:
                    with st.spinner("Dispatching reports via SMTP..."):
                        sent_count = 0
                        for b in st.session_state.last_bundles:
                            date_folder = f"{b.start.isoformat()}" if b.start == b.end else f"{b.start.isoformat()}_to_{b.end.isoformat()}"
                            out_dir = OUTPUT_ROOT / date_folder / b.store_id
                            out_dir.mkdir(parents=True, exist_ok=True)
                            base_name = f"daily_sales_{b.store_id}_{date_folder}"
                            
                            html_text = report_render.render_html(b, active_sections=active_sections)
                            html_path = out_dir / f"{base_name}.html"
                            html_path.write_text(html_text, encoding="utf-8")

                            attachments = []
                            if attach_xlsx:
                                xlsx_path = out_dir / f"{base_name}.xlsx"
                                report_render.render_xlsx(b, str(xlsx_path), active_sections=active_sections)
                                attachments.append(str(xlsx_path))

                            if attach_csv:
                                if "transactions" in active_sections:
                                    tx_csv = out_dir / f"{base_name}_transactions.csv"
                                    b.transactions.to_csv(tx_csv, index=False, encoding="utf-8-sig")
                                    attachments.append(str(tx_csv))
                                if "employees" in active_sections:
                                    emp_csv = out_dir / f"{base_name}_employees.csv"
                                    b.employees.to_csv(emp_csv, index=False, encoding="utf-8-sig")
                                    attachments.append(str(emp_csv))
                                if "voids" in active_sections:
                                    v_csv = out_dir / f"{base_name}_voids.csv"
                                    report_render.slice_audit_events(b.audit_events, "Void").to_csv(v_csv, index=False, encoding="utf-8-sig")
                                    attachments.append(str(v_csv))

                            subject = f"Daily Sales Report — {b.store_name} — {b.date_label}"
                            job = report_mailer.EmailJob(
                                to=recips, cc=[], bcc=[],
                                subject=subject,
                                html_body=html_text,
                                attachments=attachments,
                            )
                            try:
                                report_mailer.send(smtp_cfg, job)
                                sent_count += 1
                            except Exception as e:
                                st.error(f"Failed sending store {b.store_id}: {e}")

                        st.success(f"✅ Successfully dispatched {sent_count} store report(s) to: {', '.join(recips)}!")

# ---------------------------------------------------------------------------
# Tab 2: Report Modules & Section Filter
# ---------------------------------------------------------------------------

with tab_modules:
    st.subheader("🧩 Configure Report Modules & Sections")
    st.markdown("Select which sections to include in your reports, emails, and Excel sheets:")

    pcol1, pcol2, pcol3, pcol4, pcol5 = st.columns(5)
    with pcol1:
        if st.button("🌟 Complete Standard", use_container_width=True, disabled=not st.session_state.is_admin_unlocked):
            st.session_state.selected_sections = set(DEFAULT_SECTIONS)
    with pcol2:
        if st.button("📊 Sales Only", use_container_width=True, disabled=not st.session_state.is_admin_unlocked):
            st.session_state.selected_sections = {"kpis", "departments", "fixed_tax", "top_items", "hourly", "payments"}
    with pcol3:
        if st.button("👥 Staff / TimeClock", use_container_width=True, disabled=not st.session_state.is_admin_unlocked):
            st.session_state.selected_sections = {"employees"}
    with pcol4:
        if st.button("🛡️ Audit & Voids", use_container_width=True, disabled=not st.session_state.is_admin_unlocked):
            st.session_state.selected_sections = {"voids", "price_changes", "deletes"}
    with pcol5:
        if st.button("Clear All", use_container_width=True, disabled=not st.session_state.is_admin_unlocked):
            st.session_state.selected_sections = set()

    saved_raw = cfg.get("REPORT_SECTIONS", "")
    current_active = st.session_state.get("selected_sections", report_render.normalize_active_sections(saved_raw))

    categories = {
        "📊 Sales Analytics": [
            ("kpis", "Key Metrics / KPIs", "Invoice count, Gross/Net Sales, Average Ticket, Taxed/Exempt, Sales Tax, Fixed Tax, Discounts, Cash."),
            ("departments", "Sales by Department", "Departmental breakdown with item quantities, revenue, fixed taxes, and percentage of sales."),
            ("fixed_tax", "Sales by Fixed Tax Bucket", "Sales grouped by Fixed Tax amount ($0.15, $0.30, etc.) with totals."),
            ("top_items", "Top 20 Items", "Highest revenue generating items sold during the period."),
            ("hourly", "Sales by Hour", "Hourly sales distribution and invoice count throughout the day."),
            ("payments", "Payment Breakdown", "Cash, Credit Card, Debit Card, Check, Gift Card, On Account, Mobile Pay, etc."),
        ],
        "👥 Staff & Operations": [
            ("employees", "Employee Time Clock", "Employee shift count, clock in/out times, hours worked, break times, and wages."),
        ],
        "🛡️ Loss Prevention & Audit": [
            ("voids", "Voids", "Voided invoices and items with cashier ID, timestamp, and amount."),
            ("price_changes", "Price Changes / Overrides", "Item price overrides with cashier ID, old price, new price, and difference."),
            ("deletes", "Line Item Deletions", "Line items deleted before closing the invoice with cashier ID and details."),
        ],
        "📄 Detail & Export Options": [
            ("transactions", "Itemized Transactions Detail", "Full itemized line-by-line transaction log."),
        ]
    }

    updated_active = set(current_active)

    for cat_name, items in categories.items():
        st.markdown(f"#### {cat_name}")
        cols = st.columns(2)
        for i, (sec_id, title, desc) in enumerate(items):
            col = cols[i % 2]
            with col:
                checked = sec_id in updated_active
                val = st.checkbox(f"**{title}** — {desc}", value=checked, key=f"sec_{sec_id}", disabled=not st.session_state.is_admin_unlocked)
                if val:
                    updated_active.add(sec_id)
                else:
                    updated_active.discard(sec_id)

    st.session_state.selected_sections = updated_active

    st.markdown("---")
    st.markdown("#### 📎 Attachment Preferences")
    att_col1, att_col2 = st.columns(2)
    with att_col1:
        st.session_state.attach_xlsx = st.checkbox(
            "Include Formatted Excel (.xlsx) Attachment",
            value=cfg.get("ATTACH_XLSX", "true").lower() in ("true", "1", "yes"),
            disabled=not st.session_state.is_admin_unlocked
        )
    with att_col2:
        st.session_state.attach_csv = st.checkbox(
            "Include Itemized CSV Detail Attachments",
            value=cfg.get("ATTACH_CSV", "true").lower() in ("true", "1", "yes"),
            disabled=not st.session_state.is_admin_unlocked
        )

# ---------------------------------------------------------------------------
# Tab 3: Discovered Stores & DB Info
# ---------------------------------------------------------------------------

with tab_stores:
    st.subheader("🏪 Merchant Stores in dbo.Setup")
    if stores_list:
        df_stores = pd.DataFrame(stores_list)
        df_stores.columns = ["Store ID", "Store Name", "Address", "City", "Phone", "Email"]
        st.dataframe(df_stores, use_container_width=True, hide_index=True)
    else:
        st.info("No stores found yet. Click '🔄 Auto-Fetch' in the sidebar.")

    st.markdown("---")
    st.markdown("### 🗄️ Database Metadata")
    meta_col1, meta_col2, meta_col3 = st.columns(3)
    meta_col1.metric("Connected Server", server_val)
    meta_col2.metric("Database", db_val)
    meta_col3.metric("Latest Sales Date in DB", latest_sales_d or "N/A")

# ---------------------------------------------------------------------------
# Tab 4: Security & Password Manager
# ---------------------------------------------------------------------------

with tab_security:
    st.subheader("🔐 Team Password Manager & Access Control")
    st.markdown(
        "Protect server connection strings, SQL credentials, SMTP passwords, and report recipient lists. "
        "Only authorized IT/Support team members can modify connection parameters."
    )

    if not st.session_state.is_admin_unlocked:
        st.warning("🔒 You must unlock Team Mode in the sidebar to change the master password.")
    else:
        st.markdown("#### 🔑 Update Master Password")
        curr_p = st.text_input("Current Master Password", type="password", key="ch_curr_p")
        new_p1 = st.text_input("New Master Password", type="password", key="ch_new_p1")
        new_p2 = st.text_input("Confirm New Master Password", type="password", key="ch_new_p2")

        if st.button("💾 Save New Password", type="primary"):
            if not auth_guard.verify_team_password(curr_p):
                st.error("❌ Current password is incorrect.")
            elif len(new_p1) < 4:
                st.warning("Password must be at least 4 characters.")
            elif new_p1 != new_p2:
                st.warning("New password and confirmation do not match.")
            else:
                if auth_guard.change_team_password(new_p1):
                    st.success("✅ Team Master Password successfully updated!")
                else:
                    st.error("Failed to update password.")
