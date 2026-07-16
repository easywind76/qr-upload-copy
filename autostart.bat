@echo off
cd /d "%~dp0"
set TASK_NAME=FileUploadServer
set SCRIPT_PATH=%~dp0run.vbs
echo ========================================
echo  File Upload Server - Auto Start Setup
echo ========================================
echo.
echo  This will install the server to start
echo  automatically when you log into Windows.
echo.
echo  Please run this script AS ADMINISTRATOR.
echo.
pause
echo.
echo  Installing scheduled task...
schtasks /create /tn "%TASK_NAME%" /tr "wscript.exe \"%SCRIPT_PATH%\"" /sc onlogon /rl highest /f
if %ERRORLEVEL%==0 (
    echo.
    echo  [OK] Auto-start installed successfully!
    echo  The server will start each time you log in.
    echo.
    echo  To remove auto-start, run: schtasks /delete /tn "%TASK_NAME%" /f
) else (
    echo.
    echo  [FAIL] Please run as Administrator.
)
echo.
pause
