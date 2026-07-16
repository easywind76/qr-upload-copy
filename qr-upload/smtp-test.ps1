<#
.SYNOPSIS
  SMTP connectivity test for 163.com
.DESCRIPTION
  Tests basic connectivity to smtp.163.com and shows detailed error info.
#>

param(
    [string]$SmtpServer = "smtp.163.com",
    [int]$Port = 587,
    [string]$Username = "youthofnua@163.com",
    [string]$Password = ""
)

if ([string]::IsNullOrEmpty($Password)) {
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $Password = $config.smtpPassword
        $Port = $config.smtpPort
        Write-Host "Using password from config.json" -ForegroundColor Gray
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SMTP Diagnostic Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server: $SmtpServer" -ForegroundColor White
Write-Host "Port: $Port" -ForegroundColor White
Write-Host "Username: $Username" -ForegroundColor White
Write-Host ""

# Test 1: Basic TCP connectivity
Write-Host "[1/4] Testing TCP connection to $SmtpServer`:$Port ..." -ForegroundColor Yellow
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $connect = $tcp.BeginConnect($SmtpServer, $Port, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
    if ($wait) {
        $tcp.EndConnect($connect)
        Write-Host "  [OK] TCP connected" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] TCP connection timeout (5s)" -ForegroundColor Red
        Write-Host "  Reason: Server unreachable or firewall blocking" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  [FAIL] TCP connection failed: $_" -ForegroundColor Red
    exit 1
}
$tcp.Close()

# Test 2: SMTP greeting
Write-Host "[2/4] Testing SMTP greeting ..." -ForegroundColor Yellow
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect($SmtpServer, $Port)
    $stream = $tcp.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true
    $greeting = $reader.ReadLine()
    Write-Host "  [OK] SMTP greeting: $greeting" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] SMTP greeting failed: $_" -ForegroundColor Red
}
$tcp.Close()

# Test 3: SSL/TLS handshake
Write-Host "[3/4] Testing TLS handshake (port $Port) ..." -ForegroundColor Yellow
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect($SmtpServer, $Port)
    $sslStream = New-Object System.Net.Security.SslStream($tcp.GetStream(), $false)
    $sslStream.AuthenticateAsClient($SmtpServer)
    Write-Host "  [OK] TLS handshake successful" -ForegroundColor Green
    Write-Host "  Cipher: $($sslStream.CipherAlgorithm)" -ForegroundColor Gray
    Write-Host "  Key exchange: $($sslStream.KeyExchangeAlgorithm)" -ForegroundColor Gray
    $sslStream.Close()
} catch {
    Write-Host "  [FAIL] TLS handshake failed: $_" -ForegroundColor Red
}
$tcp.Close()

# Test 4: SMTP authentication
Write-Host "[4/4] Testing SMTP authentication ..." -ForegroundColor Yellow
if ([string]::IsNullOrEmpty($Password)) {
    Write-Host "  [SKIP] No password provided" -ForegroundColor Yellow
} else {
    try {
        $smtp = New-Object System.Net.Mail.SmtpClient($SmtpServer, $Port)
        $smtp.EnableSsl = $true
        $smtp.UseDefaultCredentials = $false
        $smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
        $msg = New-Object System.Net.Mail.MailMessage
        $msg.From = $Username
        $msg.To.Add($Username)
        $msg.Subject = "SMTP Test"
        $msg.Body = "This is a test email from the diagnostic tool."
        $smtp.Send($msg)
        Write-Host "  [OK] SMTP authentication and send successful!" -ForegroundColor Green
        $msg.Dispose()
        $smtp.Dispose()
    } catch {
        Write-Host "  [FAIL] SMTP send failed: $_" -ForegroundColor Red
        $inner = $_.Exception.InnerException
        while ($inner) {
            Write-Host "    Inner: $($inner.Message)" -ForegroundColor Red
            $inner = $inner.InnerException
        }
    }
}

Write-Host ""
Write-Host "Diagnostic complete." -ForegroundColor Cyan
