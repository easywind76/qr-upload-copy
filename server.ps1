<#
.SYNOPSIS
  File upload server with SMTP email delivery
.DESCRIPTION
  Starts a TCP-based HTTP server that provides a file upload page.
  Uploaded files are sent via SMTP to the configured email address.
  On first run, a config.json will be generated for SMTP settings.
#>

param(
    [int]$Port = 8080,
    [string]$ConfigPath = ""
)

if ($ConfigPath -eq "") {
    $ConfigPath = Join-Path $PSScriptRoot "config.json"
}

$ScriptDir = $PSScriptRoot
$WWWDir = Join-Path $ScriptDir "www"
$LogDir = Join-Path $ScriptDir "logs"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$config = $null
if (Test-Path $ConfigPath) {
    try {
        $rawConfig = Get-Content $ConfigPath -Raw -Encoding UTF8
        $config = $rawConfig | ConvertFrom-Json
    } catch {
        Write-Host "[!] Config file is corrupted, regenerating..." -ForegroundColor Yellow
        $config = $null
    }
}

if ($config -eq $null) {
    $configData = @{
        smtpServer = "smtp.163.com"
        smtpPort = 587
        smtpUseSSL = $true
        smtpUsername = "youthofnua@163.com"
        smtpPassword = ""
        targetEmail = "youthofnua@163.com"
        maxFileSizeMB = 25
    }
    $config = New-Object PSObject -Property $configData
    $config | ConvertTo-Json | Set-Content $ConfigPath -Encoding UTF8

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  First run - please configure SMTP" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Config created: $ConfigPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Steps:" -ForegroundColor White
    Write-Host "  1. Login to 163 mail web" -ForegroundColor White
    Write-Host "  2. Settings > POP3/SMTP/IMAP" -ForegroundColor White
    Write-Host "  3. Enable SMTP and get auth code" -ForegroundColor White
    Write-Host "  4. Edit config.json, put auth code in smtpPassword" -ForegroundColor White
    Write-Host ""
    Write-Host "Then run this script again." -ForegroundColor Green
    Write-Host ""
    exit 0
}

$SmtpServer = $config.smtpServer
$SmtpPort = $config.smtpPort
$SmtpUseSSL = $config.smtpUseSSL
if ($SmtpUseSSL -ne $true) {
    $SmtpUseSSL = $false
}
$SmtpUsername = $config.smtpUsername
$SmtpPassword = $config.smtpPassword
$TargetEmail = $config.targetEmail
$MaxFileSize = $config.maxFileSizeMB * 1MB

if ([string]::IsNullOrEmpty($SmtpPassword)) {
    Write-Host "[!] Error: smtpPassword is not configured. Please edit config.json." -ForegroundColor Red
    exit 1
}

function Write-Log {
    param([string]$Message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$time] $Message"
    Write-Host $line -ForegroundColor Gray
    Add-Content (Join-Path $LogDir "server.log") $line -Encoding UTF8
}
# Enable TLS 1.2 for SMTP
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12


function Send-EmailAttachment {
    param(
        [byte[]]$FileBytes,
        [string]$FileName,
        [string]$ContentType,
        [string]$SenderName,
        [string]$SenderEmail
    )

    try {
        $mail = New-Object System.Net.Mail.MailMessage
        $mail.From = $SmtpUsername
        $mail.To.Add($TargetEmail)
        $mail.Subject = "[File Upload] $FileName"

        $fileSizeKB = "{0:N2}" -f ($FileBytes.Length / 1KB)
        $uploadDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $senderInfo = $SenderName
        if ($senderInfo -eq "") {
            $senderInfo = "Anonymous"
        }

        $mail.Body = "New file uploaded:`r`n`r`n"
        $mail.Body = $mail.Body + "Filename: $FileName`r`n"
        $mail.Body = $mail.Body + "Type: $ContentType`r`n"
        $mail.Body = $mail.Body + "Size: $fileSizeKB KB`r`n"
        $mail.Body = $mail.Body + "Uploader: $senderInfo`r`n"
        $mail.Body = $mail.Body + "Time: $uploadDate`r`n"
        $mail.Body = $mail.Body + "`r`n---`r`n"
        $mail.Body = $mail.Body + "Sent by file upload server"

        $mail.BodyEncoding = [System.Text.Encoding]::UTF8
        $mail.SubjectEncoding = [System.Text.Encoding]::UTF8

        $ms = New-Object System.IO.MemoryStream(, $FileBytes)
        $attachment = New-Object System.Net.Mail.Attachment($ms, $FileName, $ContentType)
        $mail.Attachments.Add($attachment)
        # Ensure TLS 1.2
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12


        $smtp = New-Object System.Net.Mail.SmtpClient($SmtpServer, $SmtpPort)
        $smtp.EnableSsl = $SmtpUseSSL
        $smtp.UseDefaultCredentials = $false
        $smtp.Credentials = New-Object System.Net.NetworkCredential($SmtpUsername, $SmtpPassword)

        $smtp.Send($mail)

        $attachment.Dispose()
        $ms.Dispose()
        $mail.Dispose()
        $smtp.Dispose()

        return $true
    } catch {
        $errMsg = $_.Exception.Message
        $innerMsg = ""
        if ($_.Exception.InnerException) {
            $innerMsg = $_.Exception.InnerException.Message
            if ($_.Exception.InnerException.InnerException) {
                $innerMsg = $innerMsg + " | Inner2: " + $_.Exception.InnerException.InnerException.Message
            }
        }
        Write-Log "Email send failed: $errMsg"
        if ($innerMsg -ne "") {
            Write-Log "  Inner: $innerMsg"
        }
        return $false
    }
}

# Get local IPs
$localIPs = @()
try {
    $hostEntry = [System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName())
    foreach ($addr in $hostEntry.AddressList) {
        if ($addr.AddressFamily -eq "InterNetwork") {
            $localIPs = $localIPs + $addr.ToString()
        }
    }
} catch {
}

# Build URL list
$urls = @()
foreach ($ip in $localIPs) {
    $urls = $urls + "http://$ip`:$Port/"
}
$urls = $urls + "http://localhost:$Port/"

# ---------- HTTP helpers ----------

function Get-MimeType {
    param([string]$Extension)
    $map = @{
        ".html" = "text/html; charset=utf-8"
        ".htm" = "text/html; charset=utf-8"
        ".css" = "text/css; charset=utf-8"
        ".js" = "application/javascript; charset=utf-8"
        ".json" = "application/json; charset=utf-8"
        ".png" = "image/png"
        ".jpg" = "image/jpeg"
        ".jpeg" = "image/jpeg"
        ".gif" = "image/gif"
        ".svg" = "image/svg+xml"
        ".ico" = "image/x-icon"
    }
    if ($map.ContainsKey($Extension)) {
        return $map[$Extension]
    }
    return "application/octet-stream"
}

function Send-HTTP {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$StatusCode = 200,
        [string]$StatusMessage = "OK",
        [string]$ContentType = "text/plain; charset=utf-8",
        [byte[]]$Body = $null,
        [string]$ExtraHeaders = ""
    )

    $encoding = [System.Text.Encoding]::UTF8
    if ($Body -eq $null) { $Body = @() }

    $headerText = "HTTP/1.1 $StatusCode $StatusMessage`r`n"
    $headerText = $headerText + "Content-Type: $ContentType`r`n"
    $headerText = $headerText + "Content-Length: $($Body.Length)`r`n"
    $headerText = $headerText + "Connection: close`r`n"
    $headerText = $headerText + "Access-Control-Allow-Origin: *`r`n"
    if ($ExtraHeaders -ne "") {
        $headerText = $headerText + $ExtraHeaders
        if (-not $ExtraHeaders.EndsWith("`r`n")) {
            $headerText = $headerText + "`r`n"
        }
    }
    $headerText = $headerText + "`r`n"

    $headerBytes = $encoding.GetBytes($headerText)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($Body.Length -gt 0) {
        $Stream.Write($Body, 0, $Body.Length)
        $Stream.Flush()
    }
}

function Read-HTTPRequest {
    param([System.Net.Sockets.NetworkStream]$Stream)

    $encoding = [System.Text.Encoding]::UTF8
    $buffer = New-Object byte[] 8192
    $data = New-Object System.Collections.ArrayList
    $totalRead = 0
    $headerEnd = -1

    # Read until we have headers
    while ($headerEnd -lt 0) {
        $bytesRead = $Stream.Read($buffer, 0, $buffer.Length)
        if ($bytesRead -le 0) { break }
        [void]$data.AddRange($buffer[0..($bytesRead-1)])
        $totalRead = $totalRead + $bytesRead
        $asText = $encoding.GetString($data.ToArray())
        $headerEnd = $asText.IndexOf("`r`n`r`n")
    }

    if ($headerEnd -lt 0) {
        return $null
    }

    $allText = $encoding.GetString($data.ToArray())
    $headerSection = $allText.Substring(0, $headerEnd)
    $bodyStart = $headerEnd + 4
    $headerLines = $headerSection -split "`r`n"

    if ($headerLines.Count -eq 0) {
        return $null
    }

    # Parse request line: METHOD PATH HTTP/1.1
    $requestLine = $headerLines[0] -split " "
    if ($requestLine.Count -lt 2) {
        return $null
    }
    $method = $requestLine[0]
    $path = $requestLine[1]

    # Parse headers
    $headers = @{}
    $contentLength = 0
    for ($i = 1; $i -lt $headerLines.Count; $i++) {
        $colonPos = $headerLines[$i].IndexOf(":")
        if ($colonPos -gt 0) {
            $key = $headerLines[$i].Substring(0, $colonPos).Trim()
            $value = $headerLines[$i].Substring($colonPos + 1).Trim()
            $headers[$key] = $value
            if ($key.ToLower() -eq "content-length") {
                $contentLength = [int]::Parse($value)
            }
        }
    }

    # Read body if needed
    $body = [byte[]]@()
    if ($contentLength -gt 0) {
        $alreadyRead = $totalRead - $bodyStart
        if ($alreadyRead -ge $contentLength) {
            $body = $data.ToArray()[$bodyStart..($bodyStart + $contentLength - 1)]
        } else {
            # Still need more data
            $remain = $contentLength - $alreadyRead
            $body = New-Object byte[] $contentLength
            if ($alreadyRead -gt 0) {
                [System.Array]::Copy($data.ToArray(), $bodyStart, $body, 0, $alreadyRead)
            }
            $offset = $alreadyRead
            while ($offset -lt $contentLength) {
                $bytesRead = $Stream.Read($body, $offset, $contentLength - $offset)
                if ($bytesRead -le 0) { break }
                $offset = $offset + $bytesRead
            }
        }
    }

    $result = New-Object PSObject -Property @{
        Method = $method
        Path = $path
        Headers = $headers
        Body = $body
        ContentLength = $contentLength
    }
    return $result
}

# ---------- HTTP Server ----------
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  File Upload Server Starting..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
try {
    $listener.Start()
} catch {
    Write-Host "[!] Cannot listen on port $Port : $_" -ForegroundColor Red
    exit 1
}

Write-Host "Access URLs:" -ForegroundColor White
foreach ($u in $urls) {
    Write-Host "  $u" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "Scan QR code with your phone to upload files" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""
Write-Log "Server started on port $Port"

while ($true) {
    $client = $null
    try {
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 600000
        $client.SendTimeout = 120000
    } catch {
        Write-Log "Accept error: $_"
        continue
    }

    $stream = $null
    try {
        $stream = $client.GetStream()
        $req = Read-HTTPRequest $stream

        if ($req -eq $null) {
            Send-HTTP -Stream $stream -StatusCode 400 -StatusMessage "Bad Request" -Body ([System.Text.Encoding]::UTF8.GetBytes("Bad Request"))
            $stream.Close()
            $client.Close()
            continue
        }

        $clientIP = $client.Client.RemoteEndPoint.ToString()
        Write-Log "$($req.Method) $($req.Path) - $clientIP"

        if ($req.Method -eq "POST" -and $req.Path -eq "/upload") {
            # Parse JSON body
            $bodyText = [System.Text.Encoding]::UTF8.GetString($req.Body)
            $json = $null
            try {
                $json = $bodyText | ConvertFrom-Json
            } catch {
                $resp = '{"error":"Invalid JSON"}'
                $respBytes = [System.Text.Encoding]::UTF8.GetBytes($resp)
                Send-HTTP -Stream $stream -StatusCode 400 -StatusMessage "Bad Request" -ContentType "application/json; charset=utf-8" -Body $respBytes
                $stream.Close()
                $client.Close()
                continue
            }

            $filename = $json.filename
            $contentType = $json.contentType
            $fileData = $json.fileData
            $senderName = ""
            $senderEmail = ""
            if ($json.senderName -ne $null) { $senderName = $json.senderName }
            if ($json.senderEmail -ne $null) { $senderEmail = $json.senderEmail }

            if ([string]::IsNullOrEmpty($filename) -or [string]::IsNullOrEmpty($fileData)) {
                $resp = '{"error":"Missing filename or file data"}'
                $respBytes = [System.Text.Encoding]::UTF8.GetBytes($resp)
                Send-HTTP -Stream $stream -StatusCode 400 -StatusMessage "Bad Request" -ContentType "application/json; charset=utf-8" -Body $respBytes
                $stream.Close()
                $client.Close()
                continue
            }

            $bytes = $null
            try {
                $bytes = [System.Convert]::FromBase64String($fileData)
            } catch {
                $resp = '{"error":"Failed to decode file data"}'
                $respBytes = [System.Text.Encoding]::UTF8.GetBytes($resp)
                Send-HTTP -Stream $stream -StatusCode 400 -StatusMessage "Bad Request" -ContentType "application/json; charset=utf-8" -Body $respBytes
                $stream.Close()
                $client.Close()
                continue
            }

            if ($bytes.Length -gt $MaxFileSize) {
                $resp = '{"error":"File too large"}'
                $respBytes = [System.Text.Encoding]::UTF8.GetBytes($resp)
                Send-HTTP -Stream $stream -StatusCode 413 -StatusMessage "Request Entity Too Large" -ContentType "application/json; charset=utf-8" -Body $respBytes
                $stream.Close()
                $client.Close()
                continue
            }

            Write-Log "Received file: $filename ($($bytes.Length) bytes)"
            $sendResult = Send-EmailAttachment -FileBytes $bytes -FileName $filename -ContentType $contentType -SenderName $senderName -SenderEmail $senderEmail

            if ($sendResult) {
                Write-Log "File sent: $filename -> $TargetEmail"
                $resp = '{"success":true,"message":"File sent to email"}'
            } else {
                $resp = '{"error":"Email send failed, check SMTP config"}'
            }
            $respBytes = [System.Text.Encoding]::UTF8.GetBytes($resp)
            Send-HTTP -Stream $stream -StatusCode 200 -StatusMessage "OK" -ContentType "application/json; charset=utf-8" -Body $respBytes

        } elseif ($req.Method -eq "GET") {
            $urlPath = $req.Path

            if ($urlPath -eq "/config") {
                $configResp = @{ maxFileSizeMB = $config.maxFileSizeMB } | ConvertTo-Json
                $configBytes = [System.Text.Encoding]::UTF8.GetBytes($configResp)
                Send-HTTP -Stream $stream -StatusCode 200 -StatusMessage "OK" -ContentType "application/json; charset=utf-8" -Body $configBytes
                $stream.Close()
                $client.Close()
                continue
            }

            if ($urlPath -eq "/" -or $urlPath -eq "") {
                $filePath = Join-Path $WWWDir "index.html"
            } else {
                $cleanPath = $urlPath.TrimStart('/')
                $filePath = Join-Path $WWWDir $cleanPath
            }

            # Security check
            $resolvedPath = [System.IO.Path]::GetFullPath($filePath)
            $resolvedWww = [System.IO.Path]::GetFullPath($WWWDir)
            $pathSafe = $resolvedPath.StartsWith($resolvedWww, [System.StringComparison]::OrdinalIgnoreCase)

            if (-not $pathSafe) {
                $respBytes = [System.Text.Encoding]::UTF8.GetBytes("Forbidden")
                Send-HTTP -Stream $stream -StatusCode 403 -StatusMessage "Forbidden" -Body $respBytes
                $stream.Close()
                $client.Close()
                continue
            }

            if (Test-Path $filePath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                $mimeType = Get-MimeType $ext
                $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
                Send-HTTP -Stream $stream -StatusCode 200 -StatusMessage "OK" -ContentType $mimeType -Body $fileBytes
            } else {
                $respBytes = [System.Text.Encoding]::UTF8.GetBytes("Not Found")
                Send-HTTP -Stream $stream -StatusCode 404 -StatusMessage "Not Found" -Body $respBytes
            }

        } else {
            $respBytes = [System.Text.Encoding]::UTF8.GetBytes("Method Not Allowed")
            Send-HTTP -Stream $stream -StatusCode 405 -StatusMessage "Method Not Allowed" -Body $respBytes
        }
    } catch {
        Write-Log "Request error: $_"
        try {
            $errBytes = [System.Text.Encoding]::UTF8.GetBytes("Internal Server Error")
            Send-HTTP -Stream $stream -StatusCode 500 -StatusMessage "Internal Server Error" -Body $errBytes
        } catch {
        }
    } finally {
        try { $stream.Close() } catch {}
        try { $client.Close() } catch {}
    }
}

$listener.Stop()
*** End of File



