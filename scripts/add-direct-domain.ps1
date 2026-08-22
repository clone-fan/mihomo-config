[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Domain,
    [uri]$MosDnsController = 'http://10.0.0.2:9099',
    [switch]$RefreshDevice
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$jsonPath = Join-Path $repoRoot 'rule/direct.json'
$srsPath = Join-Path $repoRoot 'rule/direct.srs'
$proxyPath = Join-Path $repoRoot 'rule/proxy.yaml'
$singBox = Join-Path (Split-Path -Parent (Split-Path -Parent $repoRoot)) '.tmp/sing-box/sing-box-1.10.7-windows-amd64/sing-box.exe'

function ConvertTo-DomainName([string]$Value) {
    $candidate = $Value.Trim().Trim('"', "'")
    if (-not $candidate) { return $null }
    if ($candidate -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') { $candidate = "https://$candidate" }
    $uri = $null
    if (-not [uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$uri)) { throw "Invalid domain: $Value" }
    $hostName = $uri.Host.TrimEnd('.').ToLowerInvariant()
    $ip = $null
    if ([Net.IPAddress]::TryParse($hostName, [ref]$ip)) { throw "IP addresses are not supported: $Value" }
    $idn = [Globalization.IdnMapping]::new()
    return (($hostName.Split('.') | ForEach-Object { $idn.GetAscii($_) }) -join '.')
}

if (-not (Test-Path -LiteralPath $jsonPath) -or -not (Test-Path -LiteralPath $singBox)) {
    throw 'direct.json or pinned sing-box compiler is missing.'
}

$tokens = @($Domain | ForEach-Object { $_ -split '[\s,;，；]+' } | Where-Object { $_ })
$hosts = @($tokens | ForEach-Object { ConvertTo-DomainName $_ } | Sort-Object -Unique)
if ($hosts.Count -eq 0) { throw 'No valid domain was supplied.' }

if (Test-Path -LiteralPath $proxyPath) {
    $proxyRules = @(Select-String -Path $proxyPath -Pattern '^\s*-\s+(\S+)\s*$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    foreach ($domainName in $hosts) {
        $conflict = $proxyRules | Where-Object {
            $rule = $_
            if ($rule.StartsWith('+.')) { $base = $rule.Substring(2); $domainName -eq $base -or $domainName.EndsWith(".$base", [StringComparison]::OrdinalIgnoreCase) }
            else { $domainName -eq $rule }
        } | Select-Object -First 1
        if ($conflict) { throw "Direct/proxy conflict: $domainName is already covered by proxy rule $conflict. Remove it from proxy first." }
    }
}

$data = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json
$suffixes = [System.Collections.Generic.List[string]]::new()
foreach ($item in @($data.rules[0].domain_suffix)) { [void]$suffixes.Add([string]$item) }
$added = @()
foreach ($domainName in $hosts) {
    if (-not $suffixes.Contains($domainName)) { [void]$suffixes.Add($domainName); $added += $domainName }
}
if ($added.Count -gt 0) {
    $data.rules[0].domain_suffix = @($suffixes | Sort-Object)
    $json = $data | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText($jsonPath, $json + "`r`n", [Text.UTF8Encoding]::new($false))
}

& $singBox rule-set compile $jsonPath -o $srsPath
if ($LASTEXITCODE -ne 0) { throw 'direct.srs compilation failed.' }
$count = @((Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json).rules[0].domain_suffix).Count
Write-Host "Validated: $count direct suffix rules"
if ($added.Count -eq 0) { Write-Host "Already present: $($hosts -join ', ')" }

if ($added.Count -gt 0) {
    git -C $repoRoot diff --check -- rule/direct.json
    if ($LASTEXITCODE -ne 0) { throw 'direct.json diff check failed.' }
    git -C $repoRoot add -- rule/direct.json rule/direct.srs
    git -C $repoRoot commit -m "rule: add $($hosts -join ', ') to direct"
    if ($LASTEXITCODE -ne 0) { throw 'Git commit failed.' }
    git -C $repoRoot push origin HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Git push failed.' }
    Write-Host 'Published direct rules to origin/main.'
}

if ($RefreshDevice) {
    $endpoint = [uri]::new($MosDnsController, '/plugins/geosite_cn/update/direct')
    $response = Invoke-RestMethod -Method Post -Uri $endpoint -TimeoutSec 30
    Write-Host "MosDNS direct subscription refresh: $($response | ConvertTo-Json -Compress)"
    Start-Sleep -Seconds 2
    $configs = Invoke-RestMethod -Method Get -Uri ([uri]::new($MosDnsController, '/plugins/geosite_cn/config')) -TimeoutSec 15
    $directIndex = [array]::IndexOf([array]$configs.name, 'direct')
    if ($directIndex -lt 0) { throw "MosDNS geosite_cn subscription 'direct' was not found." }
    $status = $configs[$directIndex]
    $statusCount = [int]([string]$status.rule_count)
    if ($statusCount -lt $count) {
        throw "MosDNS direct subscription rule count is $statusCount, expected at least $count."
    }
    Write-Host "MosDNS direct subscription verified: $statusCount rules; updated=$($status.last_updated)"
}
