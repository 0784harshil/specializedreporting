# Specialized Reporting — 1-File Merchant Installation Guide

**Specialized Reporting** is 100% self-contained in a single executable file: **`Specialized_Reporting.exe`**.

You do **NOT** need to copy `config.env`, install Python, or copy scripts.

---

## 🚀 1-File Installation (Only 1 Step!)

### 1. Copy `Specialized_Reporting.exe`
- Copy **`Specialized_Reporting.exe`** to any folder on the merchant computer (e.g. `C:\SpecializedReporting`).
- Double-click **`Specialized_Reporting.exe`**.

*(On first launch, `Specialized_Reporting.exe` automatically creates its configuration file with default settings!)*

---

### 2. Configure Settings inside the App (Once!)
1. Click **`🔒 Restricted Mode (Click to Unlock)`** at the top right and enter your team password (`admin123`).
2. Go to **🔌 SQL Server & Discovery**:
   - Verify/Enter SQL Server Instance and Database.
   - Click **`⚡ Test Connection`**.
3. Go to **📧 Email & SMTP Dispatch**:
   - Enter your Gmail App Password and recipient email addresses.
4. Go to **⚙️ Settings & Scheduling**:
   - Set time to **`07:00 AM`**.
   - Click **`⚡ Register / Update Windows Task Schedule`**.
5. Click **`💾 Save Config`** in the left sidebar.

---

## ⚡ Background Automation & Remote Updates
* **Zero Dependencies**: Windows Task Scheduler automatically runs `Specialized_Reporting.exe --scheduled` at 7:00 AM in the background without opening a window or needing Python.
* **Auto-Updates**: When you push new releases to GitHub, `Specialized_Reporting.exe` updates itself automatically without losing the merchant's saved database connection!
