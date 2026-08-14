import os
import shutil

# Make sure we're in the right directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Find Streamlit package path
import streamlit as st
streamlit_path = os.path.dirname(st.__file__)

# Create the PyInstaller hook file to include Streamlit properly
with open('hook-streamlit.py', 'w') as f:
    f.write(f'''
from PyInstaller.utils.hooks import copy_metadata
datas = copy_metadata('streamlit')
''')

# Create the entry point script for the executable
with open('app_runner.py', 'w') as f:
    f.write('''
import os
import sys
import streamlit.web.cli as stcli

def resolve_path(path):
    resolved_path = os.path.abspath(os.path.join(os.getcwd(), path))
    return resolved_path

if __name__ == "__main__":
    # If we are running in a PyInstaller bundle
    if getattr(sys, 'frozen', False):
        application_path = sys._MEIPASS
    else:
        application_path = os.path.dirname(os.path.abspath(__file__))

    os.environ["STREAMLIT_SERVER_PORT"] = "8501"
    os.environ["STREAMLIT_SERVER_HEADLESS"] = "true"
    
    sys.argv = [
        "streamlit",
        "run",
        resolve_path("FixedTaxApp.py"),
        "--global.developmentMode=false",
    ]
    
    sys.exit(stcli.main())
''')

print("Starting PyInstaller to bundle the application. This will take several minutes...")
print("Please wait...")

# Run PyInstaller
os.system(f'pyinstaller --noconfirm --onedir --windowed --add-data "FixedTaxApp.py;." --additional-hooks-dir=. app_runner.py')

print("\\n✅ Compilation Finished!")
print("The final application is located in the 'dist/app_runner' folder.")
