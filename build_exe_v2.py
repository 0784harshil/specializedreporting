import os
import shutil

# Make sure we're in the right directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# ---- Create Streamlit Config Files ----
os.makedirs(".streamlit", exist_ok=True)
with open(".streamlit/config.toml", "w") as f:
    f.write("""
[server]
port = 8501
headless = true
enableCORS = false
enableXsrfProtection = false

[browser]
gatherUsageStats = false
""")

# ---- Create Runtime Script ----
with open('app_runner.py', 'w') as f:
    f.write('''
import os
import sys
import streamlit.web.cli as stcli
import traceback

def resolve_path(path):
    resolved_path = os.path.abspath(os.path.join(os.getcwd(), path))
    return resolved_path

if __name__ == "__main__":
    try:
        # If we are running in a PyInstaller bundle
        if getattr(sys, 'frozen', False):
            application_path = sys._MEIPASS
        else:
            application_path = os.path.dirname(os.path.abspath(__file__))

        os.environ["STREAMLIT_SERVER_PORT"] = "8501"
        os.environ["STREAMLIT_SERVER_HEADLESS"] = "true"
        os.environ["STREAMLIT_CONFIG_DIR_PATH"] = os.path.join(application_path, ".streamlit")
        
        # Point to the bundled script
        script_path = os.path.join(application_path, "FixedTaxApp.py")
        
        sys.argv = [
            "streamlit",
            "run",
            script_path,
            "--global.developmentMode=false",
        ]
        
        sys.exit(stcli.main())
    except Exception as e:
        print("CRITICAL ERROR LAUNCHING APP:")
        traceback.print_exc()
        input("Press Enter to explicitly close this window...")
''')

print("Starting robust PyInstaller Process...")
# Notice we removed --windowed so the console STAYS OPEN to show errors!
# And explicitly including the .streamlit folder
os.system(f'pyinstaller --noconfirm --onedir --add-data "FixedTaxApp.py;." --add-data ".streamlit;." --copy-metadata streamlit app_runner.py')

print("\\n✅ Compilation Finished!")
