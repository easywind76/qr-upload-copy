Write-Host "=== File Upload Server - Firewall Setup ===" -ForegroundColor Cyan
Write-Host "Adding firewall rule for port 8080..." -ForegroundColor Yellow
$result = netsh advfirewall firewall add rule name="FileUploadServer 8080" dir=in action=allow protocol=TCP localport=8080
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Firewall rule added!" -ForegroundColor Green
} else {
    Write-Host "[FAIL] $result" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running this script AS ADMINISTRATOR:" -ForegroundColor Yellow
    Write-Host "  1. Right-click the file" -ForegroundColor White
    Write-Host "  2. 'Run with PowerShell' (as admin)" -ForegroundColor White
    exit 1
}
Write-Host ""
Write-Host "Verifying rule..." -ForegroundColor Yellow
$rule = netsh advfirewall firewall show rule name="FileUploadServer 8080" 2>&1
if ($rule -match "FileUploadServer 8080") {
    Write-Host "[OK] Rule is active" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Rule not found" -ForegroundColor Red
}
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Now restart the server and test from iPhone." -ForegroundColor White
