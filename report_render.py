"""HTML + XLSX renderers for the daily sales report."""

from __future__ import annotations

import datetime as _dt
import io
from dataclasses import dataclass
from typing import Optional

import pandas as pd
from jinja2 import Environment, BaseLoader, select_autoescape
from markupsafe import Markup


# ---------------------------------------------------------------------------
# Data container
# ---------------------------------------------------------------------------

@dataclass
class ReportBundle:
    store_id: str
    merchant: dict
    start: _dt.date
    end: _dt.date
    kpis: pd.DataFrame
    by_department: pd.DataFrame
    by_fixed_tax: pd.DataFrame
    top_items: pd.DataFrame
    by_hour: pd.DataFrame
    by_payment: pd.DataFrame
    transactions: pd.DataFrame
    employees: pd.DataFrame
    audit_events: pd.DataFrame

    @property
    def date_label(self) -> str:
        if self.start == self.end:
            return self.start.isoformat()
        return f"{self.start.isoformat()} to {self.end.isoformat()}"

    @property
    def store_name(self) -> str:
        for key in ("Store_Description", "Company_Info_1"):
            v = self.merchant.get(key)
            if v is None or (isinstance(v, float) and pd.isna(v)):
                continue
            s = str(v).strip()
            if s and s.lower() != "nan":
                return s
        return f"Store {self.store_id}"


# ---------------------------------------------------------------------------
# Section Definitions & Modular Filter System
# ---------------------------------------------------------------------------

AVAILABLE_SECTIONS = {
    "kpis": {
        "title": "Key Metrics / KPIs",
        "category": "Sales Analytics",
        "description": "Invoice count, Gross/Net Sales, Average Ticket, Taxed/Exempt, Sales Tax, Fixed Tax, Discounts, Cash.",
        "default": True,
    },
    "departments": {
        "title": "Sales by Department",
        "category": "Sales Analytics",
        "description": "Departmental breakdown with item quantities, revenue, fixed taxes, and percentage of sales.",
        "default": True,
    },
    "fixed_tax": {
        "title": "Sales by Fixed Tax Bucket",
        "category": "Sales Analytics",
        "description": "Sales grouped by Fixed Tax amount ($0.15, $0.30, etc.) with totals.",
        "default": True,
    },
    "top_items": {
        "title": "Top 20 Items",
        "category": "Sales Analytics",
        "description": "Highest revenue generating items sold during the period.",
        "default": True,
    },
    "hourly": {
        "title": "Sales by Hour",
        "category": "Sales Analytics",
        "description": "Hourly sales distribution and invoice count throughout the day.",
        "default": True,
    },
    "payments": {
        "title": "Payment Breakdown",
        "category": "Sales Analytics",
        "description": "Cash, Credit Card, Debit Card, Check, Gift Card, On Account, Mobile Pay, etc.",
        "default": True,
    },
    "employees": {
        "title": "Employee Time Clock",
        "category": "Staff & Operations",
        "description": "Employee shift count, clock in/out times, hours worked, break times, and wages.",
        "default": True,
    },
    "voids": {
        "title": "Voids",
        "category": "Loss Prevention / Audit",
        "description": "Voided invoices and items with cashier ID, timestamp, and amount.",
        "default": True,
    },
    "price_changes": {
        "title": "Price Changes / Overrides",
        "category": "Loss Prevention / Audit",
        "description": "Item price overrides with cashier ID, old price, new price, and difference.",
        "default": True,
    },
    "deletes": {
        "title": "Line Item Deletions",
        "category": "Loss Prevention / Audit",
        "description": "Line items deleted before closing the invoice with cashier ID and details.",
        "default": True,
    },
    "transactions": {
        "title": "Itemized Transactions Detail",
        "category": "Detail & Export",
        "description": "Full itemized line-by-line transaction log.",
        "default": True,
    },
}

DEFAULT_SECTIONS = set(AVAILABLE_SECTIONS.keys())


def normalize_active_sections(active_sections: Optional[Iterable[str]]) -> set[str]:
    """Return a validated set of active section keys from input string or iterable."""
    if active_sections is None:
        return set(DEFAULT_SECTIONS)
    if isinstance(active_sections, str):
        raw_list = [s.strip() for s in active_sections.replace(";", ",").split(",") if s.strip()]
    else:
        raw_list = [str(s).strip() for s in active_sections if str(s).strip()]
    
    out = set()
    for s in raw_list:
        k = s.lower()
        if k in AVAILABLE_SECTIONS:
            out.add(k)
        elif k in ("dept", "department", "by_department"):
            out.add("departments")
        elif k in ("fixedtax", "by_fixed_tax", "tax_bucket", "fixed_tax_bucket"):
            out.add("fixed_tax")
        elif k in ("top", "top20", "top_20", "items", "topitems"):
            out.add("top_items")
        elif k in ("hour", "by_hour", "hours"):
            out.add("hourly")
        elif k in ("payment", "by_payment", "pay"):
            out.add("payments")
        elif k in ("time_clock", "timeclock", "employee", "staff", "wages", "hours_worked"):
            out.add("employees")
        elif k in ("void", "invoice_void"):
            out.add("voids")
        elif k in ("price_change", "override", "overrides", "price_override", "pricechanges"):
            out.add("price_changes")
        elif k in ("delete", "line_item_delete", "deleted", "deletions"):
            out.add("deletes")
        elif k in ("trans", "itemized", "detail", "transaction"):
            out.add("transactions")
        elif k in ("kpi", "metrics", "summary", "key_metrics"):
            out.add("kpis")
            
    return out if out else set(DEFAULT_SECTIONS)


# ---------------------------------------------------------------------------
# HTML rendering
# ---------------------------------------------------------------------------

_HTML_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Daily Sales Report — {{ store_name }} — {{ date_label }}</title>
</head>
<body style="margin:0;padding:0;background:#f4f5f7;font-family:Segoe UI,Arial,sans-serif;color:#222;">
<div style="max-width:860px;margin:24px auto;background:#fff;border:1px solid #e2e4e8;border-radius:8px;overflow:hidden;">

  <div style="background:#1f3b5b;color:#fff;padding:20px 28px;">
    <div style="font-size:12px;letter-spacing:1px;text-transform:uppercase;opacity:.85;">Daily Sales Report</div>
    <div style="font-size:22px;font-weight:700;margin-top:4px;">{{ store_name }}</div>
    <div style="font-size:14px;opacity:.9;margin-top:2px;">Reporting period: <strong>{{ date_label }}</strong></div>
  </div>

  <div style="padding:20px 28px;border-bottom:1px solid #eef0f3;font-size:13px;line-height:1.5;">
    <table style="border-collapse:collapse;width:100%;">
      <tr>
        <td style="vertical-align:top;padding-right:16px;">
          <div style="color:#6b7280;font-size:11px;text-transform:uppercase;">Merchant</div>
          <div><strong>{{ store_name }}</strong></div>
          {% if address %}<div>{{ address }}</div>{% endif %}
          {% if city_line %}<div>{{ city_line }}</div>{% endif %}
          {% if phone %}<div>Phone: {{ phone }}</div>{% endif %}
          {% if tax_id %}<div>Tax ID: {{ tax_id }}</div>{% endif %}
          <div>Store ID: {{ store_id }}</div>
        </td>
        <td style="vertical-align:top;">
          <div style="color:#6b7280;font-size:11px;text-transform:uppercase;">Generated</div>
          <div>{{ generated_at }}</div>
        </td>
      </tr>
    </table>
  </div>

  {% if show_kpis %}
  <!-- KPIs -->
  <div style="padding:16px 28px 8px 28px;">
    <h3 style="margin:0 0 8px 0;font-size:14px;color:#1f3b5b;text-transform:uppercase;letter-spacing:.5px;">Key Metrics</h3>
    <table style="border-collapse:collapse;width:100%;font-size:13px;">
      {% for row in kpi_rows %}
      <tr>
        {% for label, value, emphasize in row %}
        <td style="width:33%;padding:10px 12px;border:1px solid #eef0f3;background:{% if emphasize %}#f7faff{% else %}#fff{% endif %};">
          <div style="color:#6b7280;font-size:11px;text-transform:uppercase;">{{ label }}</div>
          <div style="font-size:16px;font-weight:{% if emphasize %}700{% else %}600{% endif %};margin-top:2px;">{{ value }}</div>
        </td>
        {% endfor %}
      </tr>
      {% endfor %}
    </table>
  </div>
  {% endif %}

  {% if show_departments %}{{ section("Sales by Department", department_table) }}{% endif %}
  {% if show_fixed_tax %}{{ section("Sales by Fixed Tax Bucket", fixed_tax_table) }}{% endif %}
  {% if show_top_items %}{{ section("Top 20 Items", top_items_table) }}{% endif %}
  {% if show_hourly %}{{ section("Sales by Hour", hour_table) }}{% endif %}
  {% if show_payments %}{{ section("Payment Breakdown", payment_table) }}{% endif %}
  {% if show_employees %}{{ section("Employee Time Clock", employee_table) }}{% endif %}
  {% if show_voids %}{{ section("Voids", voids_table) }}{% endif %}
  {% if show_price_changes %}{{ section("Price Changes", price_changes_table) }}{% endif %}
  {% if show_deletes %}{{ section("Deletes", deletes_table) }}{% endif %}

  <div style="padding:14px 28px 24px 28px;font-size:12px;color:#6b7280;">
    Attached detailed reports are available in <strong>.xlsx</strong> and <strong>.csv</strong> format.
  </div>
</div>
</body>
</html>
"""


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


def _fmt_int(v) -> str:
    try:
        return f"{int(v):,}"
    except Exception:
        return "0"


def _table_html(df: pd.DataFrame, money_cols: set[str] = set(),
                qty_cols: set[str] = set(), pct_cols: set[str] = set(),
                totals_row: Optional[dict] = None) -> Markup:
    if df is None or df.empty:
        return Markup(
            '<div style="padding:10px 12px;border:1px solid #eef0f3;color:#6b7280;'
            'font-size:12px;">No data for this period.</div>'
        )

    def fmt_cell(col: str, val) -> str:
        if pd.isna(val):
            return ""
        if col in money_cols:
            return _fmt_money(val)
        if col in qty_cols:
            return _fmt_qty(val)
        if col in pct_cols:
            try:
                return f"{float(val):.1f}%"
            except Exception:
                return ""
        return str(val)

    cols = list(df.columns)
    head = "".join(
        f'<th style="text-align:left;padding:8px 10px;border-bottom:2px solid #1f3b5b;'
        f'background:#f7faff;font-size:11px;text-transform:uppercase;color:#1f3b5b;">'
        f'{c.replace("_", " ").title()}</th>'
        for c in cols
    )
    body_rows = []
    for _, r in df.iterrows():
        tds = []
        for c in cols:
            align = "right" if (c in money_cols or c in qty_cols or c in pct_cols) else "left"
            tds.append(
                f'<td style="padding:6px 10px;border-bottom:1px solid #eef0f3;'
                f'text-align:{align};">{fmt_cell(c, r[c])}</td>'
            )
        body_rows.append("<tr>" + "".join(tds) + "</tr>")

    totals_html = ""
    if totals_row:
        tds = []
        for c in cols:
            v = totals_row.get(c, "")
            align = "right" if (c in money_cols or c in qty_cols or c in pct_cols) else "left"
            tds.append(
                f'<td style="padding:8px 10px;border-top:2px solid #1f3b5b;'
                f'font-weight:700;background:#f7faff;text-align:{align};">{v}</td>'
            )
        totals_html = "<tr>" + "".join(tds) + "</tr>"

    return Markup(
        '<table style="border-collapse:collapse;width:100%;font-size:12px;">'
        f'<thead><tr>{head}</tr></thead>'
        f'<tbody>{"".join(body_rows)}{totals_html}</tbody>'
        '</table>'
    )


def _section_wrap(title: str, inner_html, count=None, theme: str = "default") -> Markup:
    """Always-visible section (count/theme args ignored; kept for call compatibility)."""
    return Markup(
        f'<div style="padding:14px 28px 4px 28px;">'
        f'<h3 style="margin:0 0 8px 0;font-size:14px;color:#1f3b5b;text-transform:uppercase;'
        f'letter-spacing:.5px;">{title}</h3>{inner_html}</div>'
    )


def render_html(bundle: ReportBundle, active_sections: Optional[Iterable[str]] = None) -> str:
    act = normalize_active_sections(active_sections)
    m = bundle.merchant
    kpi = bundle.kpis.iloc[0].to_dict() if not bundle.kpis.empty else {}
    gross = float(kpi.get("gross_sales", 0) or 0)

    dept_disp = bundle.by_department.copy()
    dept_totals_row = None
    if not dept_disp.empty:
        if gross:
            dept_disp["pct_of_sales"] = (dept_disp["revenue"].astype(float) / gross * 100.0)
        else:
            dept_disp["pct_of_sales"] = 0.0
        dept_disp = dept_disp.rename(columns={
            "dept_id": "dept", "dept_name": "name", "qty": "qty",
            "revenue": "revenue", "fixed_tax_collected": "fixed_tax",
            "pct_of_sales": "pct",
        })
        dept_disp = dept_disp[["dept", "name", "qty", "revenue", "fixed_tax", "pct"]]
        dept_totals_row = {
            "dept": "TOTAL",
            "name": f"{len(dept_disp)} department(s)",
            "qty": _fmt_qty(dept_disp["qty"].astype(float).sum()),
            "revenue": _fmt_money(dept_disp["revenue"].astype(float).sum()),
            "fixed_tax": _fmt_money(dept_disp["fixed_tax"].astype(float).sum()),
            "pct": f"{dept_disp['pct'].astype(float).sum():.1f}%",
        }

    fx_disp = bundle.by_fixed_tax.copy()
    if not fx_disp.empty:
        fx_disp = fx_disp.rename(columns={
            "fixed_tax_bucket": "fixed_tax",
            "qty": "qty",
            "revenue": "revenue",
            "fixed_tax_collected": "fixed_tax_collected",
        })

    top_disp = bundle.top_items.copy()
    if not top_disp.empty:
        top_disp = top_disp.rename(columns={
            "item_num": "item_num", "item_name": "item_name",
            "qty": "qty", "revenue": "revenue",
        })

    hour_disp = bundle.by_hour.copy()
    if not hour_disp.empty:
        hour_disp["hour_of_day"] = (
            hour_disp["hour_of_day"].astype(int).map(lambda h: f"{h:02d}:00")
        )
        hour_disp = hour_disp.rename(columns={
            "hour_of_day": "hour", "invoice_count": "invoices", "revenue": "revenue",
        })

    address_parts = [str(m.get("Address") or "").strip()]
    address = ", ".join(p for p in address_parts if p)
    city = str(m.get("City") or "").strip()
    state = str(m.get("State") or "").strip()
    zipc = str(m.get("ZipCode") or "").strip()
    city_line = ", ".join(p for p in [city, state] if p)
    if zipc:
        city_line = (city_line + " " + zipc).strip()

    kpi_rows = [
        [
            ("Invoices", _fmt_int(kpi.get("invoice_count", 0)), False),
            ("Gross Sales", _fmt_money(kpi.get("pretax_sales", 0)), True),
            ("Net Sales", _fmt_money(kpi.get("gross_sales", 0)), True),
        ],
        [
            ("Average Ticket", _fmt_money(kpi.get("avg_ticket", 0)), False),
            ("Taxed Sales", _fmt_money(kpi.get("taxed_sales", 0)), False),
            ("Tax-Exempt Sales", _fmt_money(kpi.get("tax_exempt_sales", 0)), False),
        ],
        [
            ("Non-Taxed Sales", _fmt_money(kpi.get("nontaxed_sales", 0)), False),
            ("Sales Tax", _fmt_money(kpi.get("sales_tax", 0)), False),
            ("Fixed Tax Collected", _fmt_money(kpi.get("fixed_tax_collected", 0)), True),
        ],
        [
            ("Discounts", _fmt_money(kpi.get("discount_total", 0)), False),
            ("Cash Collected", _fmt_money(kpi.get("cash_collected", 0)), False),
            ("", "", False),
        ],
    ]

    env = Environment(loader=BaseLoader(), autoescape=select_autoescape(["html", "xml"]))
    tmpl = env.from_string(_HTML_TEMPLATE)

    voids_disp = _audit_display(bundle.audit_events, "Void")
    price_disp = _audit_display(bundle.audit_events, "Price Change")
    deletes_disp = _audit_display(bundle.audit_events, "Deleted")
    employee_disp = _employee_display(bundle.employees)

    html = tmpl.render(
        store_name=bundle.store_name,
        date_label=bundle.date_label,
        store_id=bundle.store_id,
        address=address,
        city_line=city_line,
        phone=str(m.get("Phone_1") or "").strip(),
        tax_id=str(m.get("Tax_ID") or "").strip(),
        generated_at=_dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        kpi_rows=kpi_rows,
        show_kpis="kpis" in act,
        show_departments="departments" in act,
        show_fixed_tax="fixed_tax" in act,
        show_top_items="top_items" in act,
        show_hourly="hourly" in act,
        show_payments="payments" in act,
        show_employees="employees" in act,
        show_voids="voids" in act,
        show_price_changes="price_changes" in act,
        show_deletes="deletes" in act,
        department_table=_table_html(
            dept_disp, money_cols={"revenue", "fixed_tax"},
            qty_cols={"qty"}, pct_cols={"pct"},
            totals_row=dept_totals_row,
        ),
        fixed_tax_table=_table_html(
            fx_disp, money_cols={"fixed_tax", "revenue", "fixed_tax_collected"},
            qty_cols={"qty"},
        ),
        top_items_table=_table_html(
            top_disp, money_cols={"revenue"}, qty_cols={"qty"},
        ),
        hour_table=_table_html(
            hour_disp, money_cols={"revenue"}, qty_cols={"invoices"},
        ),
        payment_table=_table_html(
            bundle.by_payment, money_cols={"amount"},
        ),
        employee_table=_table_html(
            employee_disp,
            money_cols={"Regular_Wages", "Overtime_Wages", "Total_Wages"},
            qty_cols={
                "Total_Shifts", "Total_Hours_Worked",
                "Unpaid_Break_Hours", "Paid_Break_Hours",
            },
        ),
        voids_table=_table_html(
            voids_disp,
            money_cols={"Amount"},
            qty_cols={"Quantity"},
        ),
        price_changes_table=_table_html(
            price_disp,
            money_cols={"Amount", "Old_Price", "New_Price"},
            qty_cols={"Quantity"},
        ),
        deletes_table=_table_html(
            deletes_disp,
            money_cols={"Amount"},
            qty_cols={"Quantity"},
        ),
        section=_section_wrap,
    )
    return html


def _audit_display(df: pd.DataFrame, action: str) -> pd.DataFrame:
    """Format one audit action type (Void / Price Change / Deleted) for HTML."""
    if df is None or df.empty or "Action" not in df.columns:
        return pd.DataFrame()
    out = df[df["Action"].astype(str) == action].copy()
    if out.empty:
        return out
    if "Event_Time" in out.columns:
        out["Event_Time"] = out["Event_Time"].apply(
            lambda v: (
                pd.Timestamp(v).strftime("%Y-%m-%d %H:%M:%S")
                if pd.notna(v) else ""
            )
        )
    if "Invoice_Number" in out.columns:
        out["Invoice_Number"] = out["Invoice_Number"].apply(
            lambda v: (
                "" if pd.isna(v)
                else str(int(v)) if float(v) == int(float(v)) else str(v)
            )
        )
    if action == "Price Change":
        cols = [
            "Event_Time", "Invoice_Number", "Cashier_ID", "Cashier_Name",
            "Item_Num", "Item_Name", "Quantity", "Amount",
            "Old_Price", "New_Price", "Details",
        ]
    else:
        cols = [
            "Event_Time", "Invoice_Number", "Cashier_ID", "Cashier_Name",
            "Item_Num", "Item_Name", "Quantity", "Amount", "Details",
        ]
    keep = [c for c in cols if c in out.columns]
    return out[keep]


def slice_audit_events(df: pd.DataFrame, action: str) -> pd.DataFrame:
    """Raw audit rows for one action (for XLSX/CSV)."""
    if df is None or df.empty or "Action" not in df.columns:
        return pd.DataFrame()
    out = df[df["Action"].astype(str) == action].copy()
    if out.empty:
        return out
    # Drop redundant Action column when writing a dedicated sheet/file.
    if "Action" in out.columns:
        out = out.drop(columns=["Action"])
    return out.reset_index(drop=True)


def _employee_display(df: pd.DataFrame) -> pd.DataFrame:
    """Format employee time-clock columns for HTML."""
    if df is None or df.empty:
        return df if df is not None else pd.DataFrame()
    out = df.copy()
    for col in ("First_Clock_In", "Last_Clock_Out"):
        if col in out.columns:
            out[col] = out[col].apply(
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
    keep = [c for c in cols if c in out.columns]
    return out[keep]


# ---------------------------------------------------------------------------
# SMS / plain-text rendering
# ---------------------------------------------------------------------------

def render_sms(bundle: ReportBundle, active_sections: Optional[Iterable[str]] = None) -> str:
    """Return a complete plain-text summary of the report suitable for SMS delivery."""
    act = normalize_active_sections(active_sections)
    lines: list[str] = []

    def h(title: str) -> None:
        lines.append(f"\n--- {title} ---")

    def m(v) -> str:
        try:
            return f"${float(v):,.2f}"
        except Exception:
            return "$0.00"

    def q(v) -> str:
        try:
            f = float(v)
            return f"{int(f):,}" if f == int(f) else f"{f:,.2f}"
        except Exception:
            return "0"

    # Header
    lines.append(f"=== {bundle.store_name} ===")
    lines.append(f"Date: {bundle.date_label}")

    # Key Metrics
    if "kpis" in act:
        kpi = bundle.kpis.iloc[0].to_dict() if not bundle.kpis.empty else {}
        h("KEY METRICS")
        lines.append(f"Invoices:      {int(kpi.get('invoice_count', 0) or 0):,}")
        lines.append(f"Gross Sales:   {m(kpi.get('pretax_sales', 0))}")
        lines.append(f"Net Sales:     {m(kpi.get('gross_sales', 0))}")
        lines.append(f"Avg Ticket:    {m(kpi.get('avg_ticket', 0))}")
        lines.append(f"Taxed Sales:   {m(kpi.get('taxed_sales', 0))}")
        lines.append(f"Tax-Exempt:    {m(kpi.get('tax_exempt_sales', 0))}")
        lines.append(f"Sales Tax:     {m(kpi.get('sales_tax', 0))}")
        lines.append(f"Fixed Tax:     {m(kpi.get('fixed_tax_collected', 0))}")
        lines.append(f"Discounts:     {m(kpi.get('discount_total', 0))}")
        lines.append(f"Cash Collected:{m(kpi.get('cash_collected', 0))}")

    # Payment Breakdown
    if "payments" in act and not bundle.by_payment.empty:
        h("PAYMENT BREAKDOWN")
        for _, row in bundle.by_payment.iterrows():
            lines.append(f"  {row['payment_type']}: {m(row['amount'])}")

    # Sales by Department
    if "departments" in act and not bundle.by_department.empty:
        h("BY DEPARTMENT")
        for _, row in bundle.by_department.iterrows():
            name = str(row.get("dept_name") or row.get("dept_id") or "").strip()
            lines.append(f"  {name}: qty {q(row['qty'])}, {m(row['revenue'])}")

    # Top Items
    if "top_items" in act and not bundle.top_items.empty:
        h("TOP ITEMS")
        for i, (_, row) in enumerate(bundle.top_items.iterrows(), 1):
            name = str(row.get("item_name") or row.get("item_num") or "").strip()
            lines.append(f"  {i}. {name}: qty {q(row['qty'])}, {m(row['revenue'])}")

    # Sales by Hour
    if "hourly" in act and not bundle.by_hour.empty:
        h("BY HOUR")
        for _, row in bundle.by_hour.iterrows():
            try:
                hr = int(row["hour_of_day"])
                hr_label = f"{hr:02d}:00"
            except Exception:
                hr_label = str(row["hour_of_day"])
            lines.append(f"  {hr_label}: {int(row['invoice_count'])} inv, {m(row['revenue'])}")

    # Transactions
    if "transactions" in act and not bundle.transactions.empty:
        h("TRANSACTIONS")
        for inv_num, grp in bundle.transactions.groupby("Invoice_Number", sort=False):
            try:
                dt_val = grp["Transaction_Date"].iloc[0]
                time_str = pd.Timestamp(dt_val).strftime("%I:%M %p")
            except Exception:
                time_str = ""
            total = m(grp["Line_Revenue"].astype(float).sum())
            lines.append(f"  INV#{inv_num} {time_str} - {total}")
            for _, item in grp.iterrows():
                iname = str(item.get("ItemName") or item.get("ItemNum") or "").strip()
                lines.append(f"    {iname} x{q(item['Quantity'])} @ {m(item['Item_Price'])}")

    # Voids / price changes / deletes (separate sections)
    if bundle.audit_events is not None and not bundle.audit_events.empty:
        audit_plan = [
            ("voids", "Void", "VOIDS"),
            ("price_changes", "Price Change", "PRICE CHANGES"),
            ("deletes", "Deleted", "DELETES"),
        ]
        for key, action, title in audit_plan:
            if key not in act:
                continue
            subset = bundle.audit_events[bundle.audit_events["Action"] == action]
            h(title)
            if subset.empty:
                lines.append("  (none)")
                continue
            for _, row in subset.iterrows():
                try:
                    time_str = pd.Timestamp(row["Event_Time"]).strftime("%Y-%m-%d %H:%M")
                except Exception:
                    time_str = str(row.get("Event_Time") or "")
                cashier = f"{row.get('Cashier_ID') or ''} {row.get('Cashier_Name') or ''}".strip()
                inv = row.get("Invoice_Number")
                inv_s = f" INV#{int(inv)}" if pd.notna(inv) else ""
                item = str(row.get("Item_Name") or row.get("Item_Num") or "").strip()
                lines.append(f"  {time_str}{inv_s} by {cashier}: {item} {m(row.get('Amount', 0))}")

    lines.append(f"\nGenerated: {_dt.datetime.now().strftime('%Y-%m-%d %H:%M')}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# XLSX rendering
# ---------------------------------------------------------------------------

def render_xlsx(bundle: ReportBundle, path: str, active_sections: Optional[Iterable[str]] = None) -> None:
    """Write a multi-sheet workbook for the report with only the requested sections."""
    act = normalize_active_sections(active_sections)
    with pd.ExcelWriter(path, engine="xlsxwriter") as writer:
        wb = writer.book
        money_fmt = wb.add_format({"num_format": "$#,##0.00"})
        qty_fmt = wb.add_format({"num_format": "#,##0.##"})
        pct_fmt = wb.add_format({"num_format": "0.0%"})
        header_fmt = wb.add_format({
            "bold": True, "bg_color": "#1f3b5b", "font_color": "#ffffff",
            "border": 1, "align": "left",
        })
        bold = wb.add_format({"bold": True})

        sheets_written = 0

        # --- Summary sheet ---
        if "kpis" in act or True:  # Summary sheet is standard cover sheet
            summary_rows: list[tuple[str, object]] = []
            m = bundle.merchant
            summary_rows += [
                ("Store ID", bundle.store_id),
                ("Store Name", bundle.store_name),
                ("Address", m.get("Address") or ""),
                ("City", m.get("City") or ""),
                ("State", m.get("State") or ""),
                ("Zip", m.get("ZipCode") or ""),
                ("Phone", m.get("Phone_1") or ""),
                ("Tax ID", m.get("Tax_ID") or ""),
                ("Report Period", bundle.date_label),
                ("Generated", _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")),
                ("", ""),
            ]
            kpi = bundle.kpis.iloc[0].to_dict() if not bundle.kpis.empty else {}
            summary_rows += [
                ("Invoice Count", int(kpi.get("invoice_count", 0) or 0)),
                ("Gross Sales", float(kpi.get("pretax_sales", 0) or 0)),
                ("Net Sales", float(kpi.get("gross_sales", 0) or 0)),
                ("Taxed Sales", float(kpi.get("taxed_sales", 0) or 0)),
                ("Tax-Exempt Sales", float(kpi.get("tax_exempt_sales", 0) or 0)),
                ("Non-Taxed Sales", float(kpi.get("nontaxed_sales", 0) or 0)),
                ("Sales Tax (Tax1+Tax2+Tax3)", float(kpi.get("sales_tax", 0) or 0)),
                ("Fixed Tax Collected", float(kpi.get("fixed_tax_collected", 0) or 0)),
                ("Discounts", float(kpi.get("discount_total", 0) or 0)),
                ("Cash Collected", float(kpi.get("cash_collected", 0) or 0)),
                ("Average Ticket", float(kpi.get("avg_ticket", 0) or 0)),
            ]
            sdf = pd.DataFrame(summary_rows, columns=["Metric", "Value"])
            sdf.to_excel(writer, sheet_name="Summary", index=False)
            ws = writer.sheets["Summary"]
            ws.set_column(0, 0, 30)
            ws.set_column(1, 1, 30)
            for i, (label, _) in enumerate(summary_rows, start=1):
                if label in {"Gross Sales", "Net Sales", "Taxed Sales", "Tax-Exempt Sales",
                             "Non-Taxed Sales", "Sales Tax (Tax1+Tax2+Tax3)",
                             "Fixed Tax Collected", "Discounts", "Cash Collected",
                             "Average Ticket"}:
                    ws.set_row(i, None, money_fmt)
            sheets_written += 1

        # --- Departments ---
        if "departments" in act:
            dept = bundle.by_department.copy()
            if not dept.empty:
                gross = float(kpi.get("gross_sales", 0) or 0)
                dept["pct_of_sales"] = (
                    dept["revenue"].astype(float) / gross if gross else 0.0
                )
            dept.to_excel(writer, sheet_name="By Department", index=False)
            _style_df(writer, "By Department", dept,
                      money_cols={"revenue", "fixed_tax_collected"},
                      qty_cols={"qty"}, pct_cols={"pct_of_sales"},
                      header_fmt=header_fmt,
                      money_fmt=money_fmt, qty_fmt=qty_fmt, pct_fmt=pct_fmt)
            sheets_written += 1

        # --- Fixed tax buckets ---
        if "fixed_tax" in act:
            bundle.by_fixed_tax.to_excel(writer, sheet_name="By Fixed Tax", index=False)
            _style_df(writer, "By Fixed Tax", bundle.by_fixed_tax,
                      money_cols={"fixed_tax_bucket", "revenue", "fixed_tax_collected"},
                      qty_cols={"qty"},
                      header_fmt=header_fmt, money_fmt=money_fmt, qty_fmt=qty_fmt,
                      pct_fmt=pct_fmt)
            sheets_written += 1

        # --- Top items ---
        if "top_items" in act:
            bundle.top_items.to_excel(writer, sheet_name="Top Items", index=False)
            _style_df(writer, "Top Items", bundle.top_items,
                      money_cols={"revenue"}, qty_cols={"qty"},
                      header_fmt=header_fmt, money_fmt=money_fmt, qty_fmt=qty_fmt,
                      pct_fmt=pct_fmt)
            sheets_written += 1

        # --- By hour ---
        if "hourly" in act:
            bundle.by_hour.to_excel(writer, sheet_name="By Hour", index=False)
            _style_df(writer, "By Hour", bundle.by_hour,
                      money_cols={"revenue"}, qty_cols={"invoice_count", "hour_of_day"},
                      header_fmt=header_fmt, money_fmt=money_fmt, qty_fmt=qty_fmt,
                      pct_fmt=pct_fmt)
            sheets_written += 1

        # --- Payments ---
        if "payments" in act:
            bundle.by_payment.to_excel(writer, sheet_name="Payments", index=False)
            _style_df(writer, "Payments", bundle.by_payment,
                      money_cols={"amount"}, qty_cols=set(),
                      header_fmt=header_fmt, money_fmt=money_fmt, qty_fmt=qty_fmt,
                      pct_fmt=pct_fmt)
            sheets_written += 1

        # --- Transactions ---
        if "transactions" in act:
            bundle.transactions.to_excel(writer, sheet_name="Transactions", index=False)
            _style_df(writer, "Transactions", bundle.transactions,
                      money_cols={"Item_Price", "Line_Revenue", "Tax1Per", "Tax2Per",
                                  "Tax3Per", "Line_Fixed_Tax", "Invoice_Total_Price",
                                  "Fixed_Tax"},
                      qty_cols={"Quantity"},
                      header_fmt=header_fmt, money_fmt=money_fmt, qty_fmt=qty_fmt,
                      pct_fmt=pct_fmt)
            sheets_written += 1

        # --- Employees (time clock) ---
        if "employees" in act:
            bundle.employees.to_excel(writer, sheet_name="Employees", index=False)
            _style_df(writer, "Employees", bundle.employees,
                      money_cols={"Regular_Wages", "Overtime_Wages", "Total_Wages"},
                      qty_cols={
                          "Total_Shifts", "Total_Hours_Worked",
                          "Unpaid_Break_Hours", "Paid_Break_Hours",
                      },
                      header_fmt=header_fmt, money_fmt=money_fmt, qty_fmt=qty_fmt,
                      pct_fmt=pct_fmt)
            sheets_written += 1

        # --- Voids / price changes / deletes (separate sheets) ---
        audit = bundle.audit_events if bundle.audit_events is not None else pd.DataFrame()
        audit_sheet_map = [
            ("voids", "Void", "Voids"),
            ("price_changes", "Price Change", "Price Changes"),
            ("deletes", "Deleted", "Deletes"),
        ]
        for key, action, sheet_name in audit_sheet_map:
            if key not in act:
                continue
            part = slice_audit_events(audit, action)
            part.to_excel(writer, sheet_name=sheet_name, index=False)
            money = {"Amount", "Old_Price", "New_Price"} if action == "Price Change" else {"Amount"}
            _style_df(writer, sheet_name, part,
                      money_cols=money,
                      qty_cols={"Quantity"},
                      header_fmt=header_fmt, money_fmt=money_fmt, qty_fmt=qty_fmt,
                      pct_fmt=pct_fmt)
            sheets_written += 1


def _style_df(writer, sheet_name: str, df: pd.DataFrame, *,
              money_cols: set[str], qty_cols: set[str],
              header_fmt, money_fmt, qty_fmt, pct_fmt,
              pct_cols: set[str] = set()) -> None:
    ws = writer.sheets[sheet_name]
    if df is None or df.empty:
        ws.write(0, 0, "No data", header_fmt)
        ws.set_column(0, 0, 40)
        return
    for col_idx, col in enumerate(df.columns):
        ws.write(0, col_idx, col, header_fmt)
        try:
            max_len = int(
                df[col]
                .map(lambda v: len(str(v)) if v is not None and not pd.isna(v) else 0)
                .max()
                or 0
            )
        except Exception:
            max_len = 0
        width = max(12, min(40, max_len + 2, len(str(col)) + 2))
        if col in money_cols:
            ws.set_column(col_idx, col_idx, max(width, 14), money_fmt)
        elif col in pct_cols:
            ws.set_column(col_idx, col_idx, max(width, 10), pct_fmt)
        elif col in qty_cols:
            ws.set_column(col_idx, col_idx, max(width, 10), qty_fmt)
        else:
            ws.set_column(col_idx, col_idx, width)
