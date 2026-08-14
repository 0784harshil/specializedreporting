import tkinter as tk
from tkinter import messagebox
import pyodbc

# GUI Configuration
class ReportConfig(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('Report Configuration')
        self.geometry('400x300')

        # Module Selection
        self.modules = tk.Listbox(self)
        self.modules.pack(pady=10)
        self.modules.insert(tk.END, 'Sales', 'Marketing', 'HR')

        # Connection Settings
        self.username = tk.Entry(self)
        self.username.pack(pady=5)
        self.password = tk.Entry(self, show='*')
        self.password.pack(pady=5)

        # Connect Button
        self.connect_btn = tk.Button(self, text='Connect to Server', command=self.connect)
        self.connect_btn.pack(pady=10)

    def connect(self):
        # Placeholder for server connection logic
        try:
            # Construct connection string with Windows auth
            conn_str = f"DRIVER={{pyodbc.drivers['ODBC Driver 17 for SQL Server']}};SERVER={{self.server_var.get()}};DATABASE=ReportDB;Trusted_Connection=yes"
            conn = pyodbc.connect(conn_str)
            messagebox.showinfo('Success', 'Connected to SQL Server with Windows auth!')
        except Exception as e:
            messagebox.showerror('Error', str(e))

if __name__ == '__main__':
    app = ReportConfig()
    app.mainloop()