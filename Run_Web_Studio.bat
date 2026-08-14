@echo off
title pcAmerica CRE Web Reporting Studio
cd /d "%~dp0"

echo ===================================================================
echo   pcAmerica CRE -- Web Reporting Studio (Streamlit)
echo ===================================================================
echo.
echo Starting Web Studio server...
echo Browser will open automatically at http://localhost:8501
echo.

if exist "C:\Users\harsh\AppData\Local\Programs\Python\Python312\python.exe" (
    "C:\Users\harsh\AppData\Local\Programs\Python\Python312\python.exe" -m streamlit run app.py --server.port 8501
    pause
    exit /b 0
)

python -m streamlit run app.py --server.port 8501
pause
