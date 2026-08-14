import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import pyodbc
import pandas as pd
from datetime import date, timedelta
import csv
import traceback
import configparser
import os
import sys

def get_base_path():
    """Get the true directory whether running as script or compiled .exe"""
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

class FixedTaxApp(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("📊 Fixed Tax Report Generation Tool")
        self.geometry("900x700")
        self.configure(padx=20, pady=20)
        
        # Set up a generic font
        self.option_add("*Font", "SegoeUI 10")
        
        # Style
        style = ttk.Style(self)
        style.theme_use('clam')
        
        # Config Manager
        self.config_file = os.path.join(get_base_path(), "settings.ini")
        self.config = configparser.ConfigParser()
        self.load_config()
        
        self.create_widgets()
        
        self.conn = None
        
    def load_config(self):
        if not os.path.exists(self.config_file):
            self.config['DATABASE'] = {
                'ServerName': 'cresqlvick',
                'DatabaseName': 'cresql'
            }
            with open(self.config_file, 'w') as configfile:
                self.config.write(configfile)
        else:
            self.config.read(self.config_file)
        
    def create_widgets(self):
        # Header
        header_frame = ttk.Frame(self)
        header_frame.pack(fill="x", pady=(0, 20))
        ttk.Label(header_frame, text="📊 Fixed Tax Report Generation Tool", font=("SegoeUI", 16, "bold")).pack(side="left")
        ttk.Label(header_frame, text="Extract transaction details based on specific Fixed Tax amounts.").pack(side="left", padx=20)
        
        # Main Layout: Settings (left) and Results (right)
        self.paned_window = ttk.PanedWindow(self, orient=tk.HORIZONTAL)
        self.paned_window.pack(fill="both", expand=True)

        self.left_frame = ttk.Frame(self.paned_window, width=300)
        self.right_frame = ttk.Frame(self.paned_window)
        
        self.paned_window.add(self.left_frame, weight=1)
        self.paned_window.add(self.right_frame, weight=3)
        
        self.setup_left_panel()
        self.setup_right_panel()

    def setup_left_panel(self):
        # DB Settings
        db_lf = ttk.LabelFrame(self.left_frame, text="⚙️ Database Settings", padding=10)
        db_lf.pack(fill="x", pady=5)
        
        ttk.Label(db_lf, text="SQL Server Name:").pack(anchor="w")
        self.server_entry = ttk.Entry(db_lf)
        self.server_entry.insert(0, self.config.get('DATABASE', 'ServerName', fallback='cresqlvick'))
        self.server_entry.pack(fill="x", pady=(0, 10))
        
        ttk.Label(db_lf, text="Database Name:").pack(anchor="w")
        self.db_entry = ttk.Entry(db_lf)
        self.db_entry.insert(0, self.config.get('DATABASE', 'DatabaseName', fallback='cresql'))
        self.db_entry.pack(fill="x", pady=(0, 10))
        
        self.auth_var = tk.StringVar(value="Windows Authentication")
        ttk.Radiobutton(db_lf, text="Windows Authentication", variable=self.auth_var, value="Windows Authentication", command=self.toggle_auth).pack(anchor="w")
        ttk.Radiobutton(db_lf, text="SQL Server Authentication", variable=self.auth_var, value="SQL Server Authentication", command=self.toggle_auth).pack(anchor="w")
        
        self.cred_frame = ttk.Frame(db_lf)
        ttk.Label(self.cred_frame, text="Username:").pack(anchor="w")
        self.user_entry = ttk.Entry(self.cred_frame)
        self.user_entry.pack(fill="x", pady=(0, 5))
        ttk.Label(self.cred_frame, text="Password:").pack(anchor="w")
        self.pwd_entry = ttk.Entry(self.cred_frame, show="*")
        self.pwd_entry.pack(fill="x", pady=(0, 10))
        # Hide creds initially
        
        self.connect_btn = ttk.Button(db_lf, text="Connect to Database", command=self.connect_db)
        self.connect_btn.pack(fill="x", pady=(10, 0))

        # Filters
        filter_lf = ttk.LabelFrame(self.left_frame, text="📅 Report Filters", padding=10)
        filter_lf.pack(fill="x", pady=5)
        
        # Start Date
        ttk.Label(filter_lf, text="Start Date (YYYY-MM-DD):").pack(anchor="w")
        self.start_date_entry = ttk.Entry(filter_lf)
        self.start_date_entry.insert(0, str(date.today() - timedelta(days=30)))
        self.start_date_entry.pack(fill="x", pady=(0, 10))
        
        # End Date
        ttk.Label(filter_lf, text="End Date (YYYY-MM-DD):").pack(anchor="w")
        self.end_date_entry = ttk.Entry(filter_lf)
        self.end_date_entry.insert(0, str(date.today()))
        self.end_date_entry.pack(fill="x", pady=(0, 10))
        
        ttk.Label(filter_lf, text="Fixed Tax Amount ($):").pack(anchor="w")
        self.tax_combo = ttk.Combobox(filter_lf, state="readonly")
        self.tax_combo.pack(fill="x", pady=(0, 10))
        
        self.run_btn = ttk.Button(filter_lf, text="🚀 Generate Report", state="disabled", command=self.generate_report)
        self.run_btn.pack(fill="x", pady=(10, 0))

    def setup_right_panel(self):
        # Status Label
        self.status_lbl = ttk.Label(self.right_frame, text="Status: Disconnected", foreground="red", font=("SegoeUI", 10, "bold"))
        self.status_lbl.pack(anchor="w", pady=(0, 10))
        
        # Metrics
        self.metrics_frame = ttk.Frame(self.right_frame)
        self.metrics_frame.pack(fill="x", pady=(0, 10))
        
        self.lbl_inv = ttk.Label(self.metrics_frame, text="Total Invoices: 0", font=("SegoeUI", 11))
        self.lbl_inv.pack(side="left", expand=True)
        self.lbl_qty = ttk.Label(self.metrics_frame, text="Total Qty: 0", font=("SegoeUI", 11))
        self.lbl_qty.pack(side="left", expand=True)
        self.lbl_rev = ttk.Label(self.metrics_frame, text="Total Rev: $0.00", font=("SegoeUI", 11))
        self.lbl_rev.pack(side="left", expand=True)
        
        # Treeview for results
        columns = ("Invoice", "Date", "Item", "Qty", "Price", "Total", "Tax")
        self.tree = ttk.Treeview(self.right_frame, columns=columns, show="headings")
        
        for col in columns:
            self.tree.heading(col, text=col)
            self.tree.column(col, width=100)
            
        scrollbar = ttk.Scrollbar(self.right_frame, orient=tk.VERTICAL, command=self.tree.yview)
        self.tree.configure(yscroll=scrollbar.set)
        
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Export Button
        self.export_btn = ttk.Button(self.right_frame, text="📥 Export CSV", state="disabled", command=self.export_csv)
        self.export_btn.pack(side="bottom", fill="x", pady=10)

    def toggle_auth(self):
        if self.auth_var.get() == "SQL Server Authentication":
            self.cred_frame.pack(fill="x", before=self.connect_btn)
        else:
            self.cred_frame.pack_forget()

    def get_driver(self):
        drivers = [x for x in pyodbc.drivers() if 'SQL Server' in x]
        if not drivers:
            raise Exception("No ODBC Driver for SQL Server found. Please install an ODBC driver.")
        return drivers[-1]

    def connect_db(self):
        server = self.server_entry.get().strip()
        db = self.db_entry.get().strip()
        auth = self.auth_var.get()
        user = self.user_entry.get().strip()
        pwd = self.pwd_entry.get().strip()
        
        try:
            driver = self.get_driver()
            if auth == "Windows Authentication":
                conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={db};Trusted_Connection=yes;Timeout=5"
            else:
                conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={db};UID={user};PWD={pwd};Timeout=5"
            
            self.status_lbl.config(text="Connecting...", foreground="orange")
            self.update()
            
            self.conn = pyodbc.connect(conn_str)
            self.status_lbl.config(text="Status: Connected ✅", foreground="green")
            
            self.load_taxes()
            self.run_btn.config(state="normal")
            
        except Exception as e:
            self.status_lbl.config(text="Status: Connection Failed ❌", foreground="red")
            messagebox.showerror("Connection Error", str(e))

    def load_taxes(self):
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
        try:
            cursor = self.conn.cursor()
            cursor.execute(query)
            taxes = [str(row[0]) for row in cursor.fetchall()]
            self.tax_combo['values'] = taxes
            if taxes:
                self.tax_combo.current(0)
        except Exception as e:
            messagebox.showerror("Query Error", f"Failed to fetch taxes: {e}")

    def generate_report(self):
        sd = self.start_date_entry.get().strip()
        ed = self.end_date_entry.get().strip()
        tax = self.tax_combo.get().strip()
        
        if not tax:
            messagebox.showwarning("Input Error", "Please select a tax amount.")
            return
            
        query = f"""
        SELECT 
            t.Invoice_Number,
            t.DateTime AS Transaction_Date,
            inv.ItemName,
            ii.Quantity,
            ii.PricePer AS Item_Price,
            (ii.Quantity * ii.PricePer) AS Line_Total,
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
        
        try:
            self.status_lbl.config(text="Running Query...", foreground="blue")
            self.update()
            
            cursor = self.conn.cursor()
            cursor.execute(query, (float(tax), sd, ed))
            rows = cursor.fetchall()
            
            # Clear old tree items
            for item in self.tree.get_children():
                self.tree.delete(item)
                
            total_inv = set()
            total_qty = 0
            total_rev = 0.0
            
            self.current_data = []
            
            for row in rows:
                inv_num, dt, itm, qty, price, total, f_tax = row
                total_inv.add(inv_num)
                total_qty += float(qty)
                total_rev += float(total)
                
                dt_str = dt.strftime("%Y-%m-%d %H:%M") if dt else ""
                
                display_row = [inv_num, dt_str, itm, f"{float(qty):.2f}", f"${float(price):.2f}", f"${float(total):.2f}", f_tax]
                self.current_data.append([inv_num, dt_str, itm, float(qty), float(price), float(total), float(f_tax)])
                self.tree.insert("", tk.END, values=display_row)
                
            self.lbl_inv.config(text=f"Total Invoices: {len(total_inv)}")
            self.lbl_qty.config(text=f"Total Qty: {total_qty:.2f}")
            self.lbl_rev.config(text=f"Total Rev: ${total_rev:.2f}")
            
            self.export_btn.config(state="normal")
            self.status_lbl.config(text=f"Status: Report Loaded ({len(rows)} records)", foreground="green")
            
        except Exception as e:
            self.status_lbl.config(text="Status: Query Error ❌", foreground="red")
            messagebox.showerror("Query Error", f"Error running report:\n{e}\n\nCheck your date format.")

    def export_csv(self):
        if not hasattr(self, 'current_data') or not self.current_data:
            return
            
        file_path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV Files", "*.csv")],
            title="Save Report As",
            initialfile=f"FixedTax_Report_{self.start_date_entry.get()}_to_{self.end_date_entry.get()}.csv"
        )
        
        if file_path:
            try:
                with open(file_path, 'w', newline='', encoding='utf-8') as f:
                    writer = csv.writer(f)
                    writer.writerow(["Invoice", "Date", "Item", "Qty", "Price", "Total", "Tax"])
                    writer.writerows(self.current_data)
                messagebox.showinfo("Export Successful", f"Saved to:\n{file_path}")
            except Exception as e:
                messagebox.showerror("Export Error", str(e))

if __name__ == "__main__":
    app = FixedTaxApp()
    app.mainloop()
