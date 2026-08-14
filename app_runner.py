
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
