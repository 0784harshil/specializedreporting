import streamlit as st
import pandas as pd
import pyodbc
import datetime
import winreg
import os

@st.cache_data(ttl=3600)
def get_local_sql_instances():
    instances = ["localhost\\SQLEXPRESS", "localhost", "(localdb)\\MSSQLLocalDB"]
    try:
        registry_key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Microsoft SQL Server")
        try:
            value, _ = winreg.QueryValueEx(registry_key, "InstalledInstances")
            hostname = os.environ.get('COMPUTERNAME', 'localhost')
            if value:
                for instance in value:
                    if instance == "MSSQLSERVER":
                        instances.append(hostname)
                    else:
                        instances.append(f"{hostname}\\{instance}")
        except FileNotFoundError:
            pass
        finally:
            winreg.CloseKey(registry_key)
    except Exception:
        pass
    
    # Remove duplicates and return
    unique_instances = []
    for i in instances:
        if i not in unique_instances:
            unique_instances.append(i)
    return unique_instances

def get_connection(server, database, auth, user, pwd):
    """Create a database connection based on sidebar inputs"""
    try:
        drivers = [x for x in pyodbc.drivers() if 'SQL Server' in x]
        if not drivers:
            return Exception("No ODBC Driver for SQL Server found on this machine.")
        driver = drivers[-1]
        
        if auth == "Windows Authentication":
            conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};Trusted_Connection=yes;"
        else:
            conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};UID={user};PWD={pwd}"
        
        return pyodbc.connect(conn_str)
    except Exception as e:
        return e

# --- UI Configuration ---
st.set_page_config(page_title="Fixed Tax Report Tool", page_icon="📊", layout="wide")
st.title("📊 Fixed Tax Report Generation Tool")
st.markdown("Extract transaction details based on specific Fixed Tax amounts and dates.")

# --- Sidebar: Database Configuration ---
with st.sidebar:
    st.header("⚙️ Database Settings")
    
    available_servers = get_local_sql_instances()
    available_servers.append("Other (Enter Manually)...")
    
    # Determine default index
    default_idx = 0
    for i, srv in enumerate(available_servers):
        if "harshil\\pcamerica" in srv.lower():
            default_idx = i
            break
            
    selected_server = st.selectbox("SQL Server Name", available_servers, index=default_idx)
    
    if selected_server == "Other (Enter Manually)...":
        server_name = st.text_input("Enter SQL Server Name manually", value="harshil\\pcamerica")
    else:
        server_name = selected_server
        
    db_name = st.text_input("Database Name", value="cresqlvick")
    
    auth_type = st.radio("Authentication Type", ["Windows Authentication", "SQL Server Authentication"])
    username = ""
    password = ""
    if auth_type == "SQL Server Authentication":
        username = st.text_input("Username")
        password = st.text_input("Password", type="password")
        
    st.markdown("---")
    st.header("📅 Report Filters")
    
    # Date Pickers
    st.markdown("##### 1. Select Date Range")
    start_date = st.date_input("Start Date", datetime.date.today() - datetime.timedelta(days=30))
    end_date = st.date_input("End Date", datetime.date.today())
    
    st.markdown("---")

def fetch_distinct_taxes(conn):
    query = """
    SELECT DISTINCT i.Fixed_Tax
    FROM [dbo].[Inventory] i
    WHERE i.Fixed_Tax IS NOT NULL
      AND UPPER(LTRIM(RTRIM(i.Dept_ID))) IN (
          '1502','1910','40% OFF','A.J','AB','ACID','AFUNTE','AGING RO','ALFONSO',
          'ASHTON','ASHTRAY','ASYLUM','ATABEY','AVO','BACCARAT','BANDOLER','BLACK',
          'BLACKEND','BOXES','BRICKHOU','BUNDLES','BUTEINE','BYRON','CALDWELL',
          'CAMACHO','CANDELS','CAO','CATELLI','CHILLIN','CHOCOLAT','CIG CASE','CIGARS',
          'CIGRILLO','CLE','COFFEE','COHIBA','COLIBRI','COUNTY T','Coupon','CROWNED',
          'CRUX','CUTTERS','DAVIDOFF','DEADWOOD','DIAMOND','DIESEL','DON KIKI','DON V',
          'dunbarto','EL SEPTI','ELIE BLE','ESPINOSA','FERIO TE','FOUND','GIFT',
          'GIFT SET','GOD OF F','GURKHA','HAVANA H','HENERY C','HERRERA','HOYO',
          'HUMICARE','HUMIDOR','HUPMAN','ILLUSION','ISABELA','isla del','J.C.NEW',
          'JAVA','JFR','JOYO DE','KRISTOFF','LA AROMA','LA AUROR','LAG','LAMPERT',
          'LARS','LES FINE','LFD','LIGA','LIGHTERS','LOST CIT','LUCIANO','MACANUDO',
          'MARRERO','MBOMBAY','MELANIO','MONTE','MY FATHE','NICARUST','NONE','NUB',
          'OLIVA','OPUSX','OSC CIG','PADRON','PAPPY','PARTAGUS','PERDOMO','PG',
          'PIPE TOB','PLASENCI','PROMETHU','PUNCH','REGIUS','ROJAS','ROMA','ROMEO',
          'RP','SAMPLER','SARZEDAS','SD','SHORTCUT','SP1014','ST-DUPON','TABAK',
          'tatiana','TATUAJE','TOSCANO','TRAVEL','TRINIDAD','UNDER','UNITED',
          'VEGA FIN','VIAJE','VINCENT','WEST TEM')
    ORDER BY i.Fixed_Tax;
    """
    df = pd.read_sql(query, conn)
    return df['Fixed_Tax'].tolist()

def fetch_report(conn, sd, ed, tax_amount):
    query = f"""
    SELECT 
        t.Invoice_Number,
        t.Store_ID,
        t.DateTime AS Transaction_Date,
        t.Total_Price AS Invoice_Total_Price,
        ii.ItemNum,
        inv.ItemName,
        ii.Quantity,
        ii.PricePer AS Item_Price,
        inv.Fixed_Tax
    FROM [dbo].[Invoice_Totals] t
    JOIN [dbo].[Invoice_Itemized] ii 
        ON t.Store_ID = ii.Store_ID AND t.Invoice_Number = ii.Invoice_Number
    JOIN [dbo].[Inventory] inv 
        ON ii.Store_ID = inv.Store_ID AND ii.ItemNum = inv.ItemNum
    WHERE inv.Fixed_Tax = ?
      AND UPPER(LTRIM(RTRIM(inv.Dept_ID))) IN (
          '1502','1910','40% OFF','A.J','AB','ACID','AFUNTE','AGING RO','ALFONSO',
          'ASHTON','ASHTRAY','ASYLUM','ATABEY','AVO','BACCARAT','BANDOLER','BLACK',
          'BLACKEND','BOXES','BRICKHOU','BUNDLES','BUTEINE','BYRON','CALDWELL',
          'CAMACHO','CANDELS','CAO','CATELLI','CHILLIN','CHOCOLAT','CIG CASE','CIGARS',
          'CIGRILLO','CLE','COFFEE','COHIBA','COLIBRI','COUNTY T','Coupon','CROWNED',
          'CRUX','CUTTERS','DAVIDOFF','DEADWOOD','DIAMOND','DIESEL','DON KIKI','DON V',
          'dunbarto','EL SEPTI','ELIE BLE','ESPINOSA','FERIO TE','FOUND','GIFT',
          'GIFT SET','GOD OF F','GURKHA','HAVANA H','HENERY C','HERRERA','HOYO',
          'HUMICARE','HUMIDOR','HUPMAN','ILLUSION','ISABELA','isla del','J.C.NEW',
          'JAVA','JFR','JOYO DE','KRISTOFF','LA AROMA','LA AUROR','LAG','LAMPERT',
          'LARS','LES FINE','LFD','LIGA','LIGHTERS','LOST CIT','LUCIANO','MACANUDO',
          'MARRERO','MBOMBAY','MELANIO','MONTE','MY FATHE','NICARUST','NONE','NUB',
          'OLIVA','OPUSX','OSC CIG','PADRON','PAPPY','PARTAGUS','PERDOMO','PG',
          'PIPE TOB','PLASENCI','PROMETHU','PUNCH','REGIUS','ROJAS','ROMA','ROMEO',
          'RP','SAMPLER','SARZEDAS','SD','SHORTCUT','SP1014','ST-DUPON','TABAK',
          'tatiana','TATUAJE','TOSCANO','TRAVEL','TRINIDAD','UNDER','UNITED',
          'VEGA FIN','VIAJE','VINCENT','WEST TEM')
      AND CAST(t.DateTime AS DATE) >= ?
      AND CAST(t.DateTime AS DATE) <= ?
    ORDER BY t.DateTime DESC;
    """
    df = pd.read_sql(query, conn, params=[tax_amount, sd, ed])
    return df

# Main App Logic
conn_result = get_connection(server_name, db_name, auth_type, username, password)

if isinstance(conn_result, Exception):
    st.error(f"❌ **Database Connection Error:** \n\n`{conn_result}`\n\nPlease check your Server and Database Name in the sidebar.")
elif conn_result is not None:
    st.success("✅ Successfully connected to database!")
    
    # Render the dynamic tax selection only if DB is connected
    with st.sidebar:
        st.markdown("##### 2. Select Fixed Tax Amount")
        with st.spinner("Loading taxes from database..."):
            try:
                available_taxes = fetch_distinct_taxes(conn_result)
                selected_tax = st.selectbox("Fixed Tax ($)", available_taxes)
            except Exception as e:
                st.error("Could not fetch tax list. Verify database structure.")
                selected_tax = None

        st.markdown("---")
        generate_btn = st.button("🚀 Generate Report", use_container_width=True, type="primary")

    if generate_btn and selected_tax is not None:
        if start_date > end_date:
            st.error("Error: Start Date cannot be after End Date.")
        else:
            with st.spinner(f"Running query for Fixed Tax ${selected_tax} between {start_date} and {end_date}..."):
                try:
                    df_report = fetch_report(conn_result, start_date, end_date, selected_tax)
                    
                    if df_report.empty:
                        st.warning(f"No records found for Fixed Tax **${selected_tax}** between **{start_date}** and **{end_date}**.")
                    else:
                        # Metrics formulation
                        total_revenue = df_report["Invoice_Total_Price"].sum()
                        total_items = df_report["Quantity"].sum()
                        total_invoices = df_report["Invoice_Number"].nunique()

                        st.markdown("### Report Summary")
                        col1, col2, col3 = st.columns(3)
                        col1.metric("Total Invoices", f"{total_invoices:,}")
                        col2.metric("Total Quantity Sold", f"{total_items:,.2f}")
                        col3.metric("Total Revenue", f"${total_revenue:,.2f}")
                        
                        st.markdown("### Transaction Data")
                        st.dataframe(df_report, use_container_width=True, hide_index=True)
                        
                        # Provide CSV download button
                        csv_data = df_report.to_csv(index=False).encode('utf-8')
                        st.download_button(
                            label="📥 Download Data as Excel/CSV",
                            data=csv_data,
                            file_name=f'FixedTax_Report_{start_date}_to_{end_date}.csv',
                            mime='text/csv'
                        )
                except Exception as e:
                    st.error(f"An error occurred running the report: {e}")
