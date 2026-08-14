"""Database access layer for the daily sales report.

All queries are scoped to the pcAmerica CRE database (cresqlvick) and use
the same Dept_ID whitelist that FixedTaxApp.py uses, so the report stays
aligned with the cigar/tobacco departments this business actually sells.
"""

from __future__ import annotations

import datetime as _dt
import os
from contextlib import contextmanager
from typing import Iterable, Optional

import pandas as pd
import pyodbc


"""
NOTE (2026-05): This report previously filtered to a hardcoded Dept_ID whitelist
to align with a specific tobacco/cigar scope. It has been changed to be fully
dynamic: all report sections now include ALL departments/items from the DB for
the store + date range (Option B).
"""


def get_available_drivers() -> list[str]:
    """Return all SQL Server ODBC drivers installed on this machine."""
    try:
        return [d for d in pyodbc.drivers() if "SQL Server" in d]
    except Exception:
        return []


def get_preferred_driver() -> str:
    """Select the best available SQL Server ODBC driver."""
    drivers = get_available_drivers()
    if not drivers:
        raise RuntimeError(
            "No ODBC 'SQL Server' driver found on this machine. "
            "Install 'ODBC Driver 17 for SQL Server' or similar."
        )
    # Prefer newer drivers if present
    priority_order = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "SQL Server Native Client 11.0",
        "SQL Server Native Client 10.0",
        "SQL Server",
    ]
    for p in priority_order:
        if p in drivers:
            return p
    return drivers[-1]


def build_connection_string(server: str, database: str, auth: str,
                            user: str = "", pwd: str = "") -> str:
    driver = get_preferred_driver()
    is_windows = auth.lower().strip() in ("windows", "trusted", "windows authentication")
    
    extra_params = "TrustServerCertificate=yes;"
    if is_windows:
        return (f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};"
                f"Trusted_Connection=yes;{extra_params}")
    return (f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};"
            f"UID={user};PWD={pwd};{extra_params}")


def test_connection(server: str, database: str, auth: str,
                    user: str = "", pwd: str = "", timeout: int = 8) -> tuple[bool, str]:
    """Test SQL Server connectivity and return (success, message)."""
    try:
        conn_str = build_connection_string(server, database, auth, user, pwd)
        conn = pyodbc.connect(conn_str, timeout=timeout)
        cursor = conn.cursor()
        cursor.execute("SELECT @@SERVERNAME, DB_NAME()")
        row = cursor.fetchone()
        srv, db = (row[0] if row else server), (row[1] if row else database)
        conn.close()
        return True, f"Connected to {srv} (Database: {db})"
    except Exception as e:
        return False, str(e)


def discover_local_sql_instances() -> list[str]:
    """Auto-detect local SQL Server instances from registry and hostname."""
    instances = ["localhost\\pcamerica", "localhost\\SQLEXPRESS", "localhost", "(localdb)\\MSSQLLocalDB"]
    hostname = os.environ.get("COMPUTERNAME", "localhost")
    instances.append(f"{hostname}\\pcamerica")
    instances.append(f"{hostname}\\SQLEXPRESS")
    instances.append(hostname)

    import winreg
    for root_key in (winreg.HKEY_LOCAL_MACHINE,):
        for sub_key_path in (
            r"SOFTWARE\Microsoft\Microsoft SQL Server",
            r"SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server",
        ):
            try:
                with winreg.OpenKey(root_key, sub_key_path) as reg_key:
                    value, _ = winreg.QueryValueEx(reg_key, "InstalledInstances")
                    if value:
                        for inst in value:
                            if inst == "MSSQLSERVER":
                                instances.append(hostname)
                                instances.append("localhost")
                            else:
                                instances.append(f"{hostname}\\{inst}")
                                instances.append(f"localhost\\{inst}")
            except Exception:
                pass

    # Preserve order while removing duplicates
    seen = set()
    unique = []
    for inst in instances:
        k = inst.strip().lower()
        if k not in seen:
            seen.add(k)
            unique.append(inst.strip())
    return unique


def fetch_server_databases(conn) -> list[str]:
    """List available databases on the connected SQL Server instance."""
    try:
        sql = """
        SELECT name FROM sys.databases
        WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')
        ORDER BY name;
        """
        df = pd.read_sql(sql, conn)
        if not df.empty and "name" in df.columns:
            return df["name"].tolist()
    except Exception:
        pass
    return ["cresqlvick", "cresql", "pcamerica"]


def _clean_str(v: object) -> str:
    if v is None:
        return ""
    if isinstance(v, float) and pd.isna(v):
        return ""
    s = str(v).strip()
    return "" if s.lower() == "nan" else s


def fetch_server_summary(conn) -> dict:
    """Fetch stores and date boundaries for quick configuration display."""
    merchants_df = fetch_merchants(conn)
    stores = []
    if not merchants_df.empty:
        for _, row in merchants_df.iterrows():
            st_id = _clean_str(row.get("Store_ID"))
            name = (
                _clean_str(row.get("Store_Description"))
                or _clean_str(row.get("Company_Info_1"))
                or f"Store {st_id}"
            )
            addr = _clean_str(row.get("Address")) or _clean_str(row.get("Company_Info_2"))
            city = _clean_str(row.get("City")) or _clean_str(row.get("Company_Info_3"))
            phone = _clean_str(row.get("Phone_1")) or _clean_str(row.get("Company_Info_4"))
            email = resolve_merchant_email(row.to_dict()) or ""
            stores.append({
                "store_id": st_id,
                "store_name": name,
                "address": addr,
                "city": city,
                "phone": phone,
                "email": email,
            })
    latest_sales = fetch_latest_sales_date(conn)
    latest_clock = fetch_latest_timeclock_date(conn)
    return {
        "stores": stores,
        "latest_sales_date": latest_sales.isoformat() if latest_sales else None,
        "latest_clock_date": latest_clock.isoformat() if latest_clock else None,
    }


@contextmanager
def open_connection(server: Optional[str] = None,
                    database: Optional[str] = None,
                    auth: Optional[str] = None,
                    user: Optional[str] = None,
                    pwd: Optional[str] = None):
    """Yield a pyodbc connection built from env vars (with optional overrides)."""
    server = server or os.getenv("SQL_SERVER", "harshil\\pcamerica")
    database = database or os.getenv("SQL_DATABASE", "cresqlvick")
    auth = auth or os.getenv("SQL_AUTH", "windows")
    user = user if user is not None else os.getenv("SQL_USER", "")
    pwd = pwd if pwd is not None else os.getenv("SQL_PASSWORD", "")

    conn_str = build_connection_string(server, database, auth, user, pwd)
    conn = pyodbc.connect(conn_str)
    try:
        yield conn
    finally:
        try:
            conn.close()
        except Exception:
            pass


# ---------------------------------------------------------------------------
# Merchant lookup
# ---------------------------------------------------------------------------

MERCHANT_SQL = """
SELECT
    s.Store_ID,
    s.Store_Description,
    s.Company_Info_1,
    s.Company_Info_2,
    s.Company_Info_3,
    s.Company_Info_4,
    s.Company_Info_5,
    s.Address,
    s.City,
    s.[State],
    s.ZipCode,
    s.Phone_1,
    s.Tax_ID,
    s.Store_Email,
    s.InetEMail,
    s.AutoBatchSettlementStatus_EmailId
FROM dbo.Setup AS s
"""


def fetch_merchants(conn, store_id: Optional[str] = None) -> pd.DataFrame:
    sql = MERCHANT_SQL
    params: list = []
    if store_id is not None:
        sql += " WHERE s.Store_ID = ?"
        params.append(store_id)
    sql += " ORDER BY s.Store_ID"
    df = pd.read_sql(sql, conn, params=params if params else None)
    return df


def fetch_latest_sales_date(conn, store_id: Optional[str] = None) -> Optional[_dt.date]:
    """Return the most recent invoice date with closed invoices."""
    sql = """
    SELECT MAX(CAST(t.DateTime AS DATE)) AS latest_date
    FROM dbo.Invoice_Totals AS t
    WHERE t.Status = 'C'
      AND ({store_filter});
    """
    store_filter = "t.Store_ID = ?" if store_id is not None else "1=1"
    sql = sql.format(store_filter=store_filter)
    params = [store_id] if store_id is not None else None
    df = pd.read_sql(sql, conn, params=params)
    if df.empty:
        return None
    val = df.loc[0, "latest_date"]
    if pd.isna(val):
        return None
    if hasattr(val, "date"):
        return val.date() if not isinstance(val, _dt.date) else val
    return val


def fetch_latest_timeclock_date(conn, store_id: Optional[str] = None) -> Optional[_dt.date]:
    """Return the most recent Time_Clock StartDateTime date."""
    sql = """
    SELECT MAX(CAST(StartDateTime AS DATE)) AS latest_date
    FROM dbo.Time_Clock
    WHERE Cashier_ID IS NOT NULL
      AND ({store_filter});
    """
    store_filter = "Store_ID = ?" if store_id is not None else "1=1"
    sql = sql.format(store_filter=store_filter)
    params = [store_id] if store_id is not None else None
    df = pd.read_sql(sql, conn, params=params)
    if df.empty:
        return None
    val = df.loc[0, "latest_date"]
    if pd.isna(val):
        return None
    if hasattr(val, "date"):
        return val.date() if not isinstance(val, _dt.date) else val
    return val


def resolve_merchant_email(row) -> Optional[str]:
    """Priority order: Store_Email -> InetEMail -> AutoBatchSettlementStatus_EmailId."""
    for col in ("Store_Email", "InetEMail", "AutoBatchSettlementStatus_EmailId"):
        val = row.get(col)
        if val is None:
            continue
        s = str(val).strip()
        if s and "@" in s:
            return s
    return None


# ---------------------------------------------------------------------------
# Sales queries (all scoped by Store_ID + date range)
# ---------------------------------------------------------------------------

def _date_params(start: _dt.date, end: _dt.date) -> tuple[str, str]:
    return start.isoformat(), end.isoformat()


def fetch_invoice_kpis(conn, store_id: str, start: _dt.date, end: _dt.date) -> pd.DataFrame:
    """One-row summary of invoice-level totals.

    Scope: line-items are summed per invoice, then aggregated across the period.

    Returns columns:
        invoice_count, gross_sales, pretax_sales, taxed_sales, tax_exempt_sales,
        nontaxed_sales, sales_tax, discount_total, cash_collected,
        fixed_tax_collected, avg_ticket

    Notes:
        pretax_sales = SUM(Grand_Total) — shown as Gross Sales
        gross_sales  = SUM(Total_Price) — shown as Net Sales
    """
    sql = f"""
    WITH scoped AS (
        SELECT
            t.Store_ID,
            t.Invoice_Number,
            MAX(t.Total_Price)       AS Total_Price,
            MAX(t.Grand_Total)       AS Grand_Total,
            MAX(t.Taxed_Sales)       AS Taxed_Sales,
            MAX(t.Tax_Exempt_Sales)  AS Tax_Exempt_Sales,
            MAX(t.NonTaxed_Sales)    AS NonTaxed_Sales,
            MAX(t.CA_Amount)         AS CA_Amount,
            MAX(t.Discount)          AS Discount,
            SUM(ii.Tax1Per + ii.Tax2Per + ii.Tax3Per) AS Line_Tax,
            SUM(ISNULL(inv.Fixed_Tax,0) * ii.Quantity) AS Fixed_Tax_Collected
        FROM dbo.Invoice_Totals AS t
        JOIN dbo.Invoice_Itemized AS ii
            ON  t.Store_ID = ii.Store_ID
            AND t.Invoice_Number = ii.Invoice_Number
        JOIN dbo.Inventory AS inv
            ON  ii.Store_ID = inv.Store_ID
            AND ii.ItemNum  = inv.ItemNum
        WHERE t.Status = 'C'
          AND t.Store_ID = ?
          AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
        GROUP BY t.Store_ID, t.Invoice_Number
    )
    SELECT
        COUNT(*)                              AS invoice_count,
        ISNULL(SUM(Total_Price),0)            AS gross_sales,
        ISNULL(SUM(Grand_Total),0)            AS pretax_sales,
        ISNULL(SUM(Taxed_Sales),0)            AS taxed_sales,
        ISNULL(SUM(Tax_Exempt_Sales),0)       AS tax_exempt_sales,
        ISNULL(SUM(NonTaxed_Sales),0)         AS nontaxed_sales,
        ISNULL(SUM(Line_Tax),0)               AS sales_tax,
        ISNULL(SUM(Discount),0)               AS discount_total,
        ISNULL(SUM(CA_Amount),0)              AS cash_collected,
        ISNULL(SUM(Fixed_Tax_Collected),0)    AS fixed_tax_collected
    FROM scoped;
    """
    s, e = _date_params(start, end)
    df = pd.read_sql(sql, conn, params=[store_id, s, e])
    if not df.empty:
        inv = df.loc[0, "invoice_count"] or 0
        gross = float(df.loc[0, "gross_sales"] or 0)
        df["avg_ticket"] = (gross / inv) if inv else 0.0
    return df


def fetch_sales_by_department(conn, store_id: str,
                              start: _dt.date, end: _dt.date) -> pd.DataFrame:
    sql = f"""
    SELECT
        inv.Dept_ID                                   AS dept_id,
        MAX(ISNULL(d.Description, inv.Dept_ID))       AS dept_name,
        SUM(ii.Quantity)                              AS qty,
        SUM(ii.PricePer * ii.Quantity)                AS revenue,
        SUM(ISNULL(inv.Fixed_Tax,0) * ii.Quantity)    AS fixed_tax_collected
    FROM dbo.Invoice_Totals AS t
    JOIN dbo.Invoice_Itemized AS ii
        ON t.Store_ID = ii.Store_ID AND t.Invoice_Number = ii.Invoice_Number
    JOIN dbo.Inventory AS inv
        ON ii.Store_ID = inv.Store_ID AND ii.ItemNum = inv.ItemNum
    LEFT JOIN dbo.Departments AS d
        ON d.Store_ID = inv.Store_ID AND d.Dept_ID = inv.Dept_ID
    WHERE t.Status = 'C'
      AND t.Store_ID = ?
      AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
    GROUP BY inv.Dept_ID
    ORDER BY revenue DESC;
    """
    s, e = _date_params(start, end)
    return pd.read_sql(sql, conn, params=[store_id, s, e])


def fetch_sales_by_fixed_tax(conn, store_id: str,
                             start: _dt.date, end: _dt.date) -> pd.DataFrame:
    sql = f"""
    SELECT
        ISNULL(inv.Fixed_Tax, 0)                      AS fixed_tax_bucket,
        SUM(ii.Quantity)                              AS qty,
        SUM(ii.PricePer * ii.Quantity)                AS revenue,
        SUM(ISNULL(inv.Fixed_Tax,0) * ii.Quantity)    AS fixed_tax_collected
    FROM dbo.Invoice_Totals AS t
    JOIN dbo.Invoice_Itemized AS ii
        ON t.Store_ID = ii.Store_ID AND t.Invoice_Number = ii.Invoice_Number
    JOIN dbo.Inventory AS inv
        ON ii.Store_ID = inv.Store_ID AND ii.ItemNum = inv.ItemNum
    WHERE t.Status = 'C'
      AND t.Store_ID = ?
      AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
    GROUP BY ISNULL(inv.Fixed_Tax, 0)
    ORDER BY fixed_tax_bucket;
    """
    s, e = _date_params(start, end)
    return pd.read_sql(sql, conn, params=[store_id, s, e])


def fetch_top_items(conn, store_id: str, start: _dt.date, end: _dt.date,
                    top_n: int = 20) -> pd.DataFrame:
    sql = f"""
    SELECT TOP ({int(top_n)})
        ii.ItemNum                                    AS item_num,
        MAX(inv.ItemName)                             AS item_name,
        SUM(ii.Quantity)                              AS qty,
        SUM(ii.PricePer * ii.Quantity)                AS revenue
    FROM dbo.Invoice_Totals AS t
    JOIN dbo.Invoice_Itemized AS ii
        ON t.Store_ID = ii.Store_ID AND t.Invoice_Number = ii.Invoice_Number
    JOIN dbo.Inventory AS inv
        ON ii.Store_ID = inv.Store_ID AND ii.ItemNum = inv.ItemNum
    WHERE t.Status = 'C'
      AND t.Store_ID = ?
      AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
    GROUP BY ii.ItemNum
    ORDER BY revenue DESC;
    """
    s, e = _date_params(start, end)
    return pd.read_sql(sql, conn, params=[store_id, s, e])


def fetch_sales_by_hour(conn, store_id: str,
                        start: _dt.date, end: _dt.date) -> pd.DataFrame:
    sql = f"""
    WITH scoped AS (
        SELECT
            t.Store_ID,
            t.Invoice_Number,
            DATEPART(HOUR, t.DateTime)   AS hour_of_day,
            MAX(t.Total_Price)           AS Total_Price
        FROM dbo.Invoice_Totals AS t
        JOIN dbo.Invoice_Itemized AS ii
            ON t.Store_ID = ii.Store_ID AND t.Invoice_Number = ii.Invoice_Number
        JOIN dbo.Inventory AS inv
            ON ii.Store_ID = inv.Store_ID AND ii.ItemNum = inv.ItemNum
        WHERE t.Status = 'C'
          AND t.Store_ID = ?
          AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
        GROUP BY t.Store_ID, t.Invoice_Number, DATEPART(HOUR, t.DateTime)
    )
    SELECT hour_of_day,
           COUNT(*)                 AS invoice_count,
           ISNULL(SUM(Total_Price),0) AS revenue
    FROM scoped
    GROUP BY hour_of_day
    ORDER BY hour_of_day;
    """
    s, e = _date_params(start, end)
    return pd.read_sql(sql, conn, params=[store_id, s, e])


def fetch_payment_breakdown(conn, store_id: str,
                            start: _dt.date, end: _dt.date) -> pd.DataFrame:
    """Aggregate the money amount columns directly off Invoice_Totals.

    Note: this counts invoice-level amounts (full invoice), because pcAmerica
    stores payment totals at the invoice level.
    """
    sql = f"""
    WITH scoped AS (
        SELECT DISTINCT t.Store_ID, t.Invoice_Number,
               t.CA_Amount, t.CH_Amount, t.CC_Amount, t.OA_Amount,
               t.GC_Amount, t.DC_Amount, t.FS_Amount, t.OP_Amount,
               t.MP_Amount, t.LAY_Amount
        FROM dbo.Invoice_Totals AS t
        JOIN dbo.Invoice_Itemized AS ii
            ON t.Store_ID = ii.Store_ID AND t.Invoice_Number = ii.Invoice_Number
        JOIN dbo.Inventory AS inv
            ON ii.Store_ID = inv.Store_ID AND ii.ItemNum = inv.ItemNum
        WHERE t.Status = 'C'
          AND t.Store_ID = ?
          AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
    )
    SELECT
        ISNULL(SUM(CA_Amount),0)  AS cash,
        ISNULL(SUM(CH_Amount),0)  AS check_amt,
        ISNULL(SUM(CC_Amount),0)  AS credit_card,
        ISNULL(SUM(OA_Amount),0)  AS on_account,
        ISNULL(SUM(GC_Amount),0)  AS gift_card,
        ISNULL(SUM(DC_Amount),0)  AS debit_card,
        ISNULL(SUM(FS_Amount),0)  AS food_stamp,
        ISNULL(SUM(OP_Amount),0)  AS other_pay,
        ISNULL(SUM(MP_Amount),0)  AS mobile_pay,
        ISNULL(SUM(LAY_Amount),0) AS layaway
    FROM scoped;
    """
    s, e = _date_params(start, end)
    row = pd.read_sql(sql, conn, params=[store_id, s, e])
    if row.empty:
        return pd.DataFrame(columns=["payment_type", "amount"])
    labels = {
        "cash": "Cash", "check_amt": "Check", "credit_card": "Credit Card",
        "on_account": "On Account", "gift_card": "Gift Card",
        "debit_card": "Debit Card", "food_stamp": "Food Stamp",
        "other_pay": "Other", "mobile_pay": "Mobile Pay", "layaway": "Layaway",
    }
    out = pd.DataFrame({
        "payment_type": [labels[k] for k in labels],
        "amount": [float(row.loc[0, k] or 0) for k in labels],
    })
    return out[out["amount"] != 0].reset_index(drop=True)


def fetch_itemized_transactions(conn, store_id: str,
                                start: _dt.date, end: _dt.date) -> pd.DataFrame:
    """Full per-line detail for the day, same JOIN pattern as FixedTaxApp.py."""
    sql = f"""
    SELECT
        t.Invoice_Number,
        t.Store_ID,
        t.DateTime                AS Transaction_Date,
        t.Cashier_ID,
        t.Station_ID,
        ii.LineNum,
        ii.ItemNum,
        inv.ItemName,
        inv.Dept_ID,
        inv.Fixed_Tax,
        ii.Quantity,
        ii.PricePer              AS Item_Price,
        (ii.Quantity * ii.PricePer) AS Line_Revenue,
        ii.Tax1Per,
        ii.Tax2Per,
        ii.Tax3Per,
        (ISNULL(inv.Fixed_Tax,0) * ii.Quantity) AS Line_Fixed_Tax,
        t.Total_Price           AS Invoice_Total_Price,
        t.Status
    FROM dbo.Invoice_Totals AS t
    JOIN dbo.Invoice_Itemized AS ii
        ON t.Store_ID = ii.Store_ID AND t.Invoice_Number = ii.Invoice_Number
    JOIN dbo.Inventory AS inv
        ON ii.Store_ID = inv.Store_ID AND ii.ItemNum = inv.ItemNum
    WHERE t.Status = 'C'
      AND t.Store_ID = ?
      AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
    ORDER BY t.DateTime, t.Invoice_Number, ii.LineNum;
    """
    s, e = _date_params(start, end)
    return pd.read_sql(sql, conn, params=[store_id, s, e])


def fetch_employee_records(conn, store_id: str,
                           start: _dt.date, end: _dt.date) -> pd.DataFrame:
    """Employee time-clock summary: shifts, hours, breaks, and wages.

    Aggregates dbo.Time_Clock by Cashier_ID + Store_ID for the date range.
    Paid/worked minutes exclude unpaid breaks; negative net minutes clamp to 0.
    """
    sql = """
    SELECT
        Cashier_ID AS Employee_ID,
        Store_ID,

        COUNT(*) AS Total_Shifts,

        MIN(StartDateTime) AS First_Clock_In,
        MAX(EndDateTime) AS Last_Clock_Out,

        CAST(
            SUM(
                CASE
                    WHEN ISNULL(
                        NumMinutes,
                        DATEDIFF(MINUTE, StartDateTime, EndDateTime)
                    ) - ISNULL(NumMinutesBreakUnpaid, 0) < 0
                    THEN 0
                    ELSE ISNULL(
                        NumMinutes,
                        DATEDIFF(MINUTE, StartDateTime, EndDateTime)
                    ) - ISNULL(NumMinutesBreakUnpaid, 0)
                END
            ) / 60.0
            AS DECIMAL(10,2)
        ) AS Total_Hours_Worked,

        CAST(
            SUM(ISNULL(NumMinutesBreakUnpaid, 0)) / 60.0
            AS DECIMAL(10,2)
        ) AS Unpaid_Break_Hours,

        CAST(
            SUM(ISNULL(NumMinutesBreakPaid, 0)) / 60.0
            AS DECIMAL(10,2)
        ) AS Paid_Break_Hours,

        CAST(
            SUM(ISNULL(Wages, 0))
            AS DECIMAL(12,2)
        ) AS Regular_Wages,

        CAST(
            SUM(ISNULL(OvertimeWagesEarned, 0))
            AS DECIMAL(12,2)
        ) AS Overtime_Wages,

        CAST(
            SUM(ISNULL(Wages, 0))
            + SUM(ISNULL(OvertimeWagesEarned, 0))
            AS DECIMAL(12,2)
        ) AS Total_Wages

    FROM dbo.Time_Clock

    WHERE StartDateTime >= ?
      AND StartDateTime < DATEADD(DAY, 1, CAST(? AS DATE))
      AND Cashier_ID IS NOT NULL
      AND Store_ID = ?

    GROUP BY
        Cashier_ID,
        Store_ID

    ORDER BY
        Cashier_ID;
    """
    s, e = _date_params(start, end)
    return pd.read_sql(sql, conn, params=[s, e, store_id])


def fetch_audit_events(conn, store_id: str,
                       start: _dt.date, end: _dt.date) -> pd.DataFrame:
    """Voids, price changes, and line-item deletes with cashier + timing.

    Sources (pcAmerica CRE):
      - Invoice_Exceptions.Reason_Code = 'Invoice Void'
      - Invoice_Exceptions.Reason_Code = 'Line Item Deletion'
      - Exceptions.Exception_Type = 21 (price change / override log)
      - Invoice_Itemized lines where origPricePer differs from PricePer
        (covers stores that do not write Exceptions type 21)
      - Invoice_Totals Status = 'V' with no matching Invoice Void exception rows
    """
    sql = """
    WITH emp AS (
        SELECT
            Cashier_ID,
            COALESCE(
                NULLIF(LTRIM(RTRIM(EmpName)), ''),
                NULLIF(LTRIM(RTRIM(Name)), ''),
                NULLIF(
                    LTRIM(RTRIM(
                        ISNULL(First_Name, '') + ' ' + ISNULL(Last_Name, '')
                    )),
                    ''
                ),
                Cashier_ID
            ) AS Cashier_Name
        FROM dbo.Employee
    ),
    voids AS (
        SELECT
            CAST('Void' AS nvarchar(20)) AS Action,
            e.DateTime AS Event_Time,
            e.Invoice_Number,
            e.Override_Cashier_ID AS Cashier_ID,
            COALESCE(
                NULLIF(LTRIM(RTRIM(e.EmpName)), ''),
                NULLIF(
                    LTRIM(RTRIM(
                        ISNULL(e.First_Name, '') + ' ' + ISNULL(e.Last_Name, '')
                    )),
                    ''
                ),
                emp.Cashier_Name,
                e.Override_Cashier_ID
            ) AS Cashier_Name,
            e.ItemNum AS Item_Num,
            ISNULL(inv.ItemName, e.ItemNum) AS Item_Name,
            e.Quantity,
            e.Amount,
            CAST(NULL AS decimal(25,8)) AS Old_Price,
            CAST(NULL AS decimal(25,8)) AS New_Price,
            e.Reason_Code AS Details
        FROM dbo.Invoice_Exceptions AS e
        LEFT JOIN emp
            ON emp.Cashier_ID = e.Override_Cashier_ID
        LEFT JOIN dbo.Inventory AS inv
            ON inv.Store_ID = e.Store_ID AND inv.ItemNum = e.ItemNum
        WHERE e.Store_ID = ?
          AND e.Reason_Code = 'Invoice Void'
          AND CAST(e.DateTime AS DATE) BETWEEN ? AND ?
    ),
    deletes AS (
        SELECT
            CAST('Deleted' AS nvarchar(20)) AS Action,
            e.DateTime AS Event_Time,
            e.Invoice_Number,
            e.Override_Cashier_ID AS Cashier_ID,
            COALESCE(
                NULLIF(LTRIM(RTRIM(e.EmpName)), ''),
                NULLIF(
                    LTRIM(RTRIM(
                        ISNULL(e.First_Name, '') + ' ' + ISNULL(e.Last_Name, '')
                    )),
                    ''
                ),
                emp.Cashier_Name,
                e.Override_Cashier_ID
            ) AS Cashier_Name,
            e.ItemNum AS Item_Num,
            ISNULL(inv.ItemName, e.ItemNum) AS Item_Name,
            e.Quantity,
            e.Amount,
            CAST(NULL AS decimal(25,8)) AS Old_Price,
            CAST(NULL AS decimal(25,8)) AS New_Price,
            e.Reason_Code AS Details
        FROM dbo.Invoice_Exceptions AS e
        LEFT JOIN emp
            ON emp.Cashier_ID = e.Override_Cashier_ID
        LEFT JOIN dbo.Inventory AS inv
            ON inv.Store_ID = e.Store_ID AND inv.ItemNum = e.ItemNum
        WHERE e.Store_ID = ?
          AND e.Reason_Code = 'Line Item Deletion'
          AND CAST(e.DateTime AS DATE) BETWEEN ? AND ?
    ),
    price_exceptions AS (
        SELECT
            CAST('Price Change' AS nvarchar(20)) AS Action,
            x.Exception_DateTime AS Event_Time,
            CAST(NULL AS bigint) AS Invoice_Number,
            COALESCE(
                NULLIF(LTRIM(RTRIM(x.Override_Cashier_ID)), ''),
                x.Cashier_ID
            ) AS Cashier_ID,
            COALESCE(
                emp_override.Cashier_Name,
                emp_cashier.Cashier_Name,
                COALESCE(
                    NULLIF(LTRIM(RTRIM(x.Override_Cashier_ID)), ''),
                    x.Cashier_ID
                )
            ) AS Cashier_Name,
            CASE
                WHEN CHARINDEX('Item:', x.Reason_Code) = 1
                     AND CHARINDEX(',Old Price:', x.Reason_Code) > 0
                THEN SUBSTRING(
                    x.Reason_Code,
                    6,
                    CHARINDEX(',Old Price:', x.Reason_Code) - 6
                )
                ELSE NULL
            END AS Item_Num,
            CAST(NULL AS nvarchar(30)) AS Item_Name,
            CAST(NULL AS decimal(25,8)) AS Quantity,
            CAST(NULL AS decimal(25,8)) AS Amount,
            TRY_CONVERT(
                decimal(25,8),
                CASE
                    WHEN CHARINDEX('Old Price:', x.Reason_Code) > 0
                         AND CHARINDEX(', New Price:', x.Reason_Code) >
                             CHARINDEX('Old Price:', x.Reason_Code)
                    THEN SUBSTRING(
                        x.Reason_Code,
                        CHARINDEX('Old Price:', x.Reason_Code) + 10,
                        CHARINDEX(', New Price:', x.Reason_Code)
                            - (CHARINDEX('Old Price:', x.Reason_Code) + 10)
                    )
                    ELSE NULL
                END
            ) AS Old_Price,
            TRY_CONVERT(
                decimal(25,8),
                CASE
                    WHEN CHARINDEX('New Price:', x.Reason_Code) > 0
                    THEN SUBSTRING(
                        x.Reason_Code,
                        CHARINDEX('New Price:', x.Reason_Code) + 10,
                        50
                    )
                    ELSE NULL
                END
            ) AS New_Price,
            x.Reason_Code AS Details
        FROM dbo.Exceptions AS x
        LEFT JOIN emp AS emp_cashier
            ON emp_cashier.Cashier_ID = x.Cashier_ID
        LEFT JOIN emp AS emp_override
            ON emp_override.Cashier_ID = x.Override_Cashier_ID
        WHERE x.Store_ID = ?
          AND x.Exception_Type = 21
          AND CAST(x.Exception_DateTime AS DATE) BETWEEN ? AND ?
          AND x.Reason_Code LIKE 'Item:%Old Price:%New Price:%'
    ),
    price_itemized AS (
        SELECT
            CAST('Price Change' AS nvarchar(20)) AS Action,
            t.DateTime AS Event_Time,
            t.Invoice_Number,
            t.Cashier_ID,
            COALESCE(emp.Cashier_Name, t.Cashier_ID) AS Cashier_Name,
            ii.ItemNum AS Item_Num,
            ISNULL(inv.ItemName, ii.ItemNum) AS Item_Name,
            ii.Quantity,
            (ii.PricePer - ii.origPricePer) * ii.Quantity AS Amount,
            ii.origPricePer AS Old_Price,
            ii.PricePer AS New_Price,
            CAST('Invoice line price override' AS nvarchar(100)) AS Details
        FROM dbo.Invoice_Itemized AS ii
        JOIN dbo.Invoice_Totals AS t
            ON t.Store_ID = ii.Store_ID
           AND t.Invoice_Number = ii.Invoice_Number
        LEFT JOIN emp
            ON emp.Cashier_ID = t.Cashier_ID
        LEFT JOIN dbo.Inventory AS inv
            ON inv.Store_ID = ii.Store_ID AND inv.ItemNum = ii.ItemNum
        WHERE t.Store_ID = ?
          AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
          AND t.Status IN ('C', 'V', 'O')
          AND ii.origPricePer IS NOT NULL
          AND ii.origPricePer <> ii.PricePer
          -- Prefer Exceptions type-21 rows when that log is populated for the day;
          -- still keep itemized overrides so invoice# / qty are visible.
    ),
    voids_invoice_fallback AS (
        SELECT
            CAST('Void' AS nvarchar(20)) AS Action,
            t.DateTime AS Event_Time,
            t.Invoice_Number,
            t.Cashier_ID,
            COALESCE(emp.Cashier_Name, t.Cashier_ID) AS Cashier_Name,
            CAST(NULL AS nvarchar(20)) AS Item_Num,
            CAST('(full invoice)' AS nvarchar(30)) AS Item_Name,
            CAST(NULL AS decimal(25,8)) AS Quantity,
            t.Total_Price AS Amount,
            CAST(NULL AS decimal(25,8)) AS Old_Price,
            CAST(NULL AS decimal(25,8)) AS New_Price,
            CAST('Invoice Status=V' AS nvarchar(100)) AS Details
        FROM dbo.Invoice_Totals AS t
        LEFT JOIN emp
            ON emp.Cashier_ID = t.Cashier_ID
        WHERE t.Store_ID = ?
          AND t.Status = 'V'
          AND CAST(t.DateTime AS DATE) BETWEEN ? AND ?
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.Invoice_Exceptions AS e
              WHERE e.Store_ID = t.Store_ID
                AND e.Invoice_Number = t.Invoice_Number
                AND e.Reason_Code = 'Invoice Void'
          )
    )
    SELECT * FROM voids
    UNION ALL
    SELECT * FROM deletes
    UNION ALL
    SELECT * FROM price_exceptions
    UNION ALL
    SELECT * FROM price_itemized
    UNION ALL
    SELECT * FROM voids_invoice_fallback
    ORDER BY Event_Time, Action, Invoice_Number, Item_Num;
    """
    s, e = _date_params(start, end)
    params = [
        store_id, s, e,  # voids
        store_id, s, e,  # deletes
        store_id, s, e,  # price_exceptions
        store_id, s, e,  # price_itemized
        store_id, s, e,  # voids_invoice_fallback
    ]
    return pd.read_sql(sql, conn, params=params)
