import os

# Make sure we're in the right directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

print("Starting PyInstaller to bundle the Native Desktop Application...")
print("Please wait...")

# Run PyInstaller for the Tkinter app
# --windowed ensures no black console pops up for the end user
# --onefile makes it a single .exe
os.system(f'pyinstaller --noconfirm --onefile --windowed DesktopTaxApp.py')

print("\\n✅ Compilation Finished!")
print("The final application is located in the 'dist/DesktopTaxApp.exe'.")
