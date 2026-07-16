@echo off
cd /d "%~dp0"
echo ========================================
echo  File Upload Server Launcher
echo ========================================
echo.
echo  Select mode:
echo  1. Normal (LAN access - recommended: run as admin)
echo  2. Local only
echo.
set /p choice="Enter 1 or 2 (default 1): "
if "%choice%"=="2" (
    powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1" -Port 8080
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1" -Port 8080
)
echo.
pause
