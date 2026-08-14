# Specialized Reporting — Merchant Deployment & Installation Guide

A step-by-step guide for deploying **Specialized Reporting** on any merchant POS machine or back-office computer.

---

## 📋 System Requirements
- **Operating System**: Windows 10, Windows 11, or Windows Server (64-bit)
- **POS Database**: pcAmerica CRE (SQL Server instance)
- **Database Driver**: ODBC Driver 17/18 for SQL Server or SQL Server Native Client *(Standard on all pcAmerica POS installations)*
- **Python**: **NOT required** (the standalone `.exe` includes everything)

---

## 🚀 3-Minute Installation Steps

### Step 1: Create an App Directory
On the target merchant computer, create a dedicated folder, for example:
```
C:\SpecializedReporting
```

### Step 2: Copy Application Files
Copy these files into `C:\SpecializedReporting`:
1. **`Specialized_Reporting.exe`** *(The standalone application)*
2. **`config.env.example`** *(Configuration template)*
3. Rename `config.env.example` to **`config.env`** *(or copy an existing `config.env`)*

---

### Step 3: Launch the Studio
- Double-click **`Specialized_Reporting.exe`**.
- The application will start in **Restricted Merchant Mode** (windowless, zero console).

---

### Step 4: Unlock Team Mode
- Click the red **`🔒 Restricted Mode (Click to Unlock)`** button at the top right.
- Enter the IT / Support Team password *(Default: `admin123`)*.

---

### Step 5: Configure SQL Server Connection
- Navigate to **🔌 SQL Server & Discovery**:
  - **SQL Instance**: Enter the instance (e.g. `.\pcamerica`, `localhost\pcamerica`, or `Harshil\pcamerica`).
  - **Database Name**: Select or enter the database (e.g. `cresqlvick`).
  - **Authentication**: Choose **SQL Authentication** (`sa` / `pcAmer1ca`) or **Windows Authentication**.
  - Click **`⚡ Test Connection`** to verify.
  - Click **`🔄 Auto-Fetch Server Details`** to populate store names and dates from `dbo.Setup`.

---

### Step 6: Configure Email & SMTP
- Navigate to **📧 Email & SMTP Dispatch**:
  - **SMTP Host**: `smtp.gmail.com` (Port: `587`, STARTTLS enabled).
  - **SMTP User**: Your dispatch Gmail address.
  - **Google App Password**: 16-character Google App Password.
  - **Recipients**: Enter the store owner / accountant emails (comma-separated).
  - Click **`✉️ Send Test Email`** to confirm delivery.

---

### Step 7: Enable Automated Daily Scheduling (7:00 AM)
- Navigate to **⚙️ Settings & Scheduling**:
  - Set **Daily Dispatch Time** to **`07:00 AM`**.
  - Check **`Enable Windows Automated Task Dispatch`**.
  - Click **`⚡ Register / Update Windows Task Schedule`**.
  - Windows Task Scheduler will now automatically generate and dispatch daily sales reports every morning at 7:00 AM in the background!

---

### Step 8: Save Configuration
- Click **`💾 Save Config`** in the left sidebar.
- Your settings are permanently saved to `config.env`.

---

## 🔄 How Remote Updates Work on Client Machines

Once installed:
1. **Zero Configuration Maintenance**:
   - When you publish an update to GitHub, the application detects it on startup.
   - It downloads the new version and replaces `Specialized_Reporting.exe`.
   - **The merchant's `config.env` and database credentials are NEVER overwritten.**
2. **Forced Updates**:
   - If you flag an update as mandatory in `version.json`, the app will automatically upgrade and restart upon launch.
