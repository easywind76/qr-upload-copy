Write-Host "Downloading QRCode.js for offline use..." -ForegroundColor Yellow
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"
    $out = Join-Path $PSScriptRoot "www" "qrcode.min.js"
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    Write-Host "[OK] Downloaded! ($((Get-Item $out).Length) bytes)" -ForegroundColor Green
    Write-Host "QR codes now work without internet." -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Could not download. Check your internet connection." -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Download manually:" -ForegroundColor Yellow
    Write-Host "  1. Open this URL in your browser:" -ForegroundColor White
    Write-Host "     https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js" -ForegroundColor Cyan
    Write-Host "  2. Save the file as: www\qrcode.min.js" -ForegroundColor White
    Write-Host "     (in the qr-upload folder)" -ForegroundColor White
}
Write-Host ""
Read-Host "Press Enter to exit"
