@echo off
cd /d "%~dp0"
echo Looking for server on port 8080...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8080 "') do (
    taskkill /f /pid %%a >nul 2>&1
)
echo Server stopped. You can close this window.
pause
