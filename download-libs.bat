@echo off
cd /d "%~dp0"
echo Downloading QRCode.js for offline use...
powershell -ExecutionPolicy Bypass -File "%~dp0download-libs.ps1"
echo.
pause
