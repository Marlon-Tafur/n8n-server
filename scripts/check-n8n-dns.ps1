# =============================================================
# check-n8n-dns.ps1 — DNS and OpenAI connectivity diagnostic
# Usage: .\scripts\check-n8n-dns.ps1
# =============================================================
#Requires -Version 5.1

$ErrorActionPreference = "Continue"

function Write-Section($title) {
    Write-Host "`n=== $title ===" -ForegroundColor Yellow
}

function Test-DNS {
    param([string]$Container, [string]$Hostname)
    Write-Host "  dns $Hostname ... " -NoNewline
    $code = @"
require('dns').lookup('$Hostname', (err, addr, fam) => {
  if (err) { process.stdout.write('FAIL:' + err.code); process.exit(1); }
  process.stdout.write('OK:' + addr + ':IPv' + fam);
});
"@
    $result = docker exec $Container node -e $code 2>&1
    if ($LASTEXITCODE -eq 0 -and $result -match "^OK:") {
        Write-Host $result.Replace("OK:", "") -ForegroundColor Green
        return $true
    } else {
        Write-Host "FAIL ($result)" -ForegroundColor Red
        return $false
    }
}

function Test-OpenAI-HTTPS {
    param([string]$Container)
    Write-Host "  https api.openai.com/v1/models ... " -NoNewline
    $code = @'
const https = require('https');
const req = https.request(
  { hostname: 'api.openai.com', path: '/v1/models', method: 'GET', timeout: 10000 },
  (res) => { process.stdout.write('HTTP:' + res.statusCode); process.exit(0); }
);
req.on('timeout', () => { process.stdout.write('FAIL:TIMEOUT'); req.destroy(); process.exit(1); });
req.on('error', (e) => { process.stdout.write('FAIL:' + e.code + ':' + e.message); process.exit(1); });
req.end();
'@
    $result = docker exec $Container node -e $code 2>&1
    if ($result -match "HTTP:401") {
        Write-Host "HTTP 401 (correct — OpenAI reached, no API key sent)" -ForegroundColor Green
        return $true
    } elseif ($result -match "HTTP:2\d\d") {
        Write-Host "$result" -ForegroundColor Green
        return $true
    } else {
        Write-Host "FAIL ($result)" -ForegroundColor Red
        return $false
    }
}

function Test-Container {
    param([string]$Name)
    Write-Section "Container: $Name"

    $running = docker inspect $Name --format "{{.State.Running}}" 2>$null
    if ($running -ne "true") {
        Write-Host "  Container not running — skipping." -ForegroundColor DarkGray
        return $null
    }

    $dns1 = Test-DNS -Container $Name -Hostname "api.openai.com"
    $dns2 = Test-DNS -Container $Name -Hostname "google.com"
    $http = Test-OpenAI-HTTPS -Container $Name

    return ($dns1 -and $dns2 -and $http)
}

# ---------------------------------------------------------------
$results = @{}
$results["n8n-app"]    = Test-Container -Name "n8n-app"
$results["n8n-worker"] = Test-Container -Name "n8n-worker"

Write-Section "Summary"
$anyFail = $false
foreach ($c in $results.Keys) {
    $r = $results[$c]
    if ($null -eq $r) {
        Write-Host "  $c : not running" -ForegroundColor DarkGray
    } elseif ($r) {
        Write-Host "  $c : OK" -ForegroundColor Green
    } else {
        Write-Host "  $c : FAIL" -ForegroundColor Red
        $anyFail = $true
    }
}

if ($anyFail) {
    Write-Host "`nTo apply fixes and recreate containers:" -ForegroundColor Cyan
    Write-Host "  docker compose -f compose.yml -f compose.local.yml -f compose.queue.yml --profile queue up -d --force-recreate n8n n8n-worker"
    Write-Host "`nSee docs/troubleshooting-dns-openai.md for details." -ForegroundColor Cyan
    exit 1
} else {
    Write-Host "`nAll checks passed." -ForegroundColor Green
    exit 0
}
