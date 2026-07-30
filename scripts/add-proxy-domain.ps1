[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [Alias('Target')]
    [string[]]$Domain,

    [ValidateSet('suffix', 'exact')]
    [string]$Mode = 'suffix',

    [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),

    [string]$MihomoPath,

    [switch]$Publish,

    [switch]$RefreshDevice,

    [uri]$Controller = 'http://10.0.0.2:9090'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$MihomoVersion = 'v1.19.29'
$MihomoAssets = @{
    windows = @{
        Name = 'mihomo-windows-amd64-compatible-v1.19.29.zip'
        Sha256 = '322aaa5957ba9e72afdda9b71cc4329f691d2d45ec39e70bbca3f7bf5aa93d52'
    }
    linux = @{
        Name = 'mihomo-linux-amd64-compatible-v1.19.29.gz'
        Sha256 = '5612e698e96c8b8ad15abc4c0a4f098eba9234354b4f248cb97f2528e215b094'
    }
}

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $script:RepoRoot @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

function ConvertTo-DomainName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $candidate = $Value.Trim().Trim('"', "'")
    if (-not $candidate) {
        return $null
    }

    $candidate = $candidate -replace '^\+\.', '' -replace '^\*\.', ''
    if ($candidate -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        $candidate = "https://$candidate"
    }

    $uriValue = $null
    if (-not [uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$uriValue)) {
        throw "Invalid domain or URL: $Value"
    }

    $hostName = $uriValue.Host.TrimEnd('.').ToLowerInvariant()
    $parsedAddress = $null
    if ([Net.IPAddress]::TryParse($hostName, [ref]$parsedAddress)) {
        throw "IP addresses are not supported: $Value"
    }

    try {
        $idn = [Globalization.IdnMapping]::new()
        $hostName = ($hostName.Split('.') | ForEach-Object { $idn.GetAscii($_) }) -join '.'
    }
    catch {
        throw "Invalid international domain: $Value"
    }

    if ($hostName.Length -gt 253 -or $hostName -notmatch '^[a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9_])?(?:\.[a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9_])?)+$') {
        throw "Invalid domain: $Value"
    }

    return $hostName
}

function Get-MihomoExecutable {
    if ($MihomoPath) {
        $resolved = (Resolve-Path -LiteralPath $MihomoPath).Path
        return $resolved
    }

    $isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    $platform = if ($isWindowsHost) { 'windows' } else { 'linux' }
    $asset = $MihomoAssets[$platform]
    $toolDirectory = Join-Path $script:RepoRoot ".tools/mihomo-$MihomoVersion-$platform"
    $executable = Join-Path $toolDirectory $(if ($isWindowsHost) { 'mihomo.exe' } else { 'mihomo' })

    if (Test-Path -LiteralPath $executable -PathType Leaf) {
        return $executable
    }

    New-Item -ItemType Directory -Force -Path $toolDirectory | Out-Null
    $archive = Join-Path $toolDirectory $asset.Name
    $downloadUrl = "https://github.com/MetaCubeX/mihomo/releases/download/$MihomoVersion/$($asset.Name)"

    Write-Host "Downloading pinned Mihomo converter $MihomoVersion..."
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile $archive
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
    if ($actualHash -ne $asset.Sha256) {
        Remove-Item -LiteralPath $archive -Force
        throw "Mihomo archive checksum mismatch. Expected $($asset.Sha256), got $actualHash."
    }

    if ($isWindowsHost) {
        Expand-Archive -LiteralPath $archive -DestinationPath $toolDirectory -Force
        $downloadedExecutable = Get-ChildItem -LiteralPath $toolDirectory -Filter 'mihomo*.exe' -File | Select-Object -First 1
        if (-not $downloadedExecutable) {
            throw 'Mihomo executable was not found in the downloaded archive.'
        }
        if ($downloadedExecutable.FullName -ne $executable) {
            Move-Item -LiteralPath $downloadedExecutable.FullName -Destination $executable -Force
        }
    }
    else {
        $inputStream = [IO.File]::OpenRead($archive)
        try {
            $gzipStream = [IO.Compression.GZipStream]::new($inputStream, [IO.Compression.CompressionMode]::Decompress)
            try {
                $outputStream = [IO.File]::Create($executable)
                try { $gzipStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
            }
            finally { $gzipStream.Dispose() }
        }
        finally { $inputStream.Dispose() }
        & chmod +x $executable
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to mark the Mihomo converter as executable.'
        }
    }

    return $executable
}

function Invoke-MihomoConvert {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string]$InputFormat,
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    & $Executable convert-ruleset domain $InputFormat $InputPath $OutputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Mihomo ruleset conversion from $InputFormat failed."
    }
}

function Get-DeviceRuleCount {
    param([Parameter(Mandatory = $true)][hashtable]$Headers)

    $providerResponse = Invoke-RestMethod -Method Get -Uri ([uri]::new($Controller, '/providers/rules')) -Headers $Headers -TimeoutSec 10
    return [int]$providerResponse.providers.my_proxy.ruleCount
}

$script:RepoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
$yamlPath = Join-Path $script:RepoRoot 'rule/proxy.yaml'
$mrsPath = Join-Path $script:RepoRoot 'rule/proxy.mrs'

if (-not (Test-Path -LiteralPath $yamlPath -PathType Leaf) -or -not (Test-Path -LiteralPath $mrsPath -PathType Leaf)) {
    throw "Not a mihomo-config repository: $script:RepoRoot"
}

if ($Publish) {
    $targetStatus = @(Invoke-Git -Arguments @('status', '--porcelain', '--', 'rule/proxy.yaml', 'rule/proxy.mrs'))
    if ($targetStatus.Count -gt 0) {
        throw 'rule/proxy.yaml or rule/proxy.mrs already has uncommitted changes. Commit or stash them first.'
    }
}

$tokens = @($Domain | ForEach-Object { $_ -split '[\s,;，；]+' } | Where-Object { $_ })
$hostNames = @($tokens | ForEach-Object { ConvertTo-DomainName -Value $_ } | Sort-Object -Unique)
if ($hostNames.Count -eq 0) {
    throw 'No valid domain was supplied.'
}

$sourceText = [IO.File]::ReadAllText($yamlPath)
$newLine = if ([regex]::Matches($sourceText, "`r`n").Count -ge [regex]::Matches($sourceText, '(?<!\r)\n').Count) { "`r`n" } else { "`n" }
$payloadMatch = [regex]::Match($sourceText, '(?m)^payload:\s*(?:\r?\n|$)')
if (-not $payloadMatch.Success) {
    throw 'rule/proxy.yaml does not contain a payload section.'
}

$payloadText = $sourceText.Substring($payloadMatch.Index + $payloadMatch.Length)
$ruleRows = @([regex]::Matches($payloadText, '(?m)^\s{2}-\s+(\S+)\s*$') | ForEach-Object {
    [pscustomobject]@{ Rule = $_.Groups[1].Value }
})
if ($ruleRows.Count -eq 0) {
    throw 'rule/proxy.yaml does not contain any domain rules.'
}

$existingRules = @($ruleRows.Rule)
$duplicateRules = @($existingRules | Group-Object | Where-Object Count -gt 1)
if ($duplicateRules.Count -gt 0) {
    throw "Duplicate rules already exist: $($duplicateRules.Name -join ', ')"
}

$rulesToAdd = [Collections.Generic.List[string]]::new()
$covered = [Collections.Generic.List[string]]::new()
foreach ($hostName in $hostNames) {
    $rule = if ($Mode -eq 'suffix') { "+.$hostName" } else { $hostName }
    $coveringRule = $existingRules | Where-Object {
        if ($_.StartsWith('+.')) {
            $baseDomain = $_.Substring(2)
            return $hostName -eq $baseDomain -or $hostName.EndsWith(".$baseDomain", [StringComparison]::OrdinalIgnoreCase)
        }
        return $_ -eq $hostName
    } | Select-Object -First 1

    if ($coveringRule) {
        $covered.Add("$hostName ($coveringRule)")
    }
    elseif (-not $rulesToAdd.Contains($rule)) {
        $rulesToAdd.Add($rule)
    }
}

if ($rulesToAdd.Count -gt 0) {
    $suffixRules = @($rulesToAdd | Where-Object { $_.StartsWith('+.') } | Sort-Object)
    $exactRules = @($rulesToAdd | Where-Object { -not $_.StartsWith('+.') } | Sort-Object)
    $updatedText = $sourceText

    if ($suffixRules.Count -gt 0) {
        $firstExactMatch = [regex]::Match($updatedText, '(?m)^\s{2}-\s+(?!\+\.)\S+')
        $suffixBlock = (@($suffixRules | ForEach-Object { "  - $_" }) -join $newLine) + $newLine
        if ($firstExactMatch.Success) {
            $updatedText = $updatedText.Insert($firstExactMatch.Index, $suffixBlock)
        }
        else {
            $lastRuleMatch = @([regex]::Matches($updatedText, '(?m)^\s{2}-\s+\S+[^\r\n]*(?:\r\n|\n|$)'))[-1]
            $insertAt = $lastRuleMatch.Index + $lastRuleMatch.Length
            if ($lastRuleMatch.Value.EndsWith("`n")) {
                $updatedText = $updatedText.Insert($insertAt, $suffixBlock)
            }
            else {
                $updatedText = $updatedText.Insert($insertAt, $newLine + $suffixBlock.TrimEnd("`r", "`n"))
            }
        }
    }

    if ($exactRules.Count -gt 0) {
        $lastRuleMatch = @([regex]::Matches($updatedText, '(?m)^\s{2}-\s+\S+[^\r\n]*(?:\r\n|\n|$)'))[-1]
        $insertAt = $lastRuleMatch.Index + $lastRuleMatch.Length
        $exactBlock = @($exactRules | ForEach-Object { "  - $_" }) -join $newLine
        if ($lastRuleMatch.Value.EndsWith("`n")) {
            $updatedText = $updatedText.Insert($insertAt, $exactBlock + $newLine)
        }
        else {
            $updatedText = $updatedText.Insert($insertAt, $newLine + $exactBlock)
        }
    }

    [IO.File]::WriteAllText($yamlPath, $updatedText, [Text.UTF8Encoding]::new($false))
}

$converter = Get-MihomoExecutable
$temporaryMrs = [IO.Path]::GetTempFileName()
$decodedRules = [IO.Path]::GetTempFileName()
try {
    Invoke-MihomoConvert -Executable $converter -InputFormat yaml -InputPath $yamlPath -OutputPath $temporaryMrs
    Invoke-MihomoConvert -Executable $converter -InputFormat mrs -InputPath $temporaryMrs -OutputPath $decodedRules

    $sourceRules = @([regex]::Matches([IO.File]::ReadAllText($yamlPath), '(?m)^\s{2}-\s+(\S+)\s*$') | ForEach-Object { $_.Groups[1].Value })
    $decoded = @([IO.File]::ReadAllLines($decodedRules) | Where-Object { $_ })
    if ($sourceRules.Count -ne $decoded.Count) {
        throw "MRS validation failed: YAML has $($sourceRules.Count) rules, decoded MRS has $($decoded.Count)."
    }
    foreach ($rule in $sourceRules) {
        if ($decoded -notcontains $rule) {
            throw "MRS validation failed: missing $rule"
        }
    }

    Move-Item -LiteralPath $temporaryMrs -Destination $mrsPath -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryMrs) { Remove-Item -LiteralPath $temporaryMrs -Force }
    if (Test-Path -LiteralPath $decodedRules) { Remove-Item -LiteralPath $decodedRules -Force }
}

$ruleCount = @([regex]::Matches([IO.File]::ReadAllText($yamlPath), '(?m)^\s{2}-\s+\S+\s*$')).Count
$mrsHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mrsPath).Hash

if ($rulesToAdd.Count -gt 0) {
    Write-Host "Added: $($rulesToAdd -join ', ')"
}
if ($covered.Count -gt 0) {
    Write-Host "Already covered: $($covered -join ', ')"
}
Write-Host "Validated: $ruleCount rules; proxy.mrs SHA-256 $mrsHash"

if ($Publish -and $rulesToAdd.Count -gt 0) {
    Invoke-Git -Arguments @('diff', '--check', '--', 'rule/proxy.yaml') | Out-Null
    Invoke-Git -Arguments @('add', '--', 'rule/proxy.yaml', 'rule/proxy.mrs') | Out-Null
    $messageTargets = ($hostNames -join ', ')
    if ($messageTargets.Length -gt 60) { $messageTargets = "$($hostNames.Count) proxy domains" }
    Invoke-Git -Arguments @('commit', '-m', "rule: add $messageTargets", '--only', '--', 'rule/proxy.yaml', 'rule/proxy.mrs') | Out-Null
    $branch = (Invoke-Git -Arguments @('branch', '--show-current') | Select-Object -First 1).Trim()
    if (-not $branch) { throw 'Cannot publish from a detached HEAD.' }
    Invoke-Git -Arguments @('push', 'origin', "HEAD:$branch") | Out-Null
    Write-Host "Published to origin/$branch."
}

if ($RefreshDevice) {
    if ($rulesToAdd.Count -gt 0 -and -not $Publish) {
        throw '-RefreshDevice requires -Publish when new rules were added.'
    }

    $headers = @{}
    if ($env:MIHOMO_SECRET) {
        $headers.Authorization = "Bearer $($env:MIHOMO_SECRET)"
    }

    $refreshUri = [uri]::new($Controller, '/providers/rules/my_proxy')
    $deviceCount = -1
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        Invoke-RestMethod -Method Put -Uri $refreshUri -Headers $headers -TimeoutSec 15 | Out-Null
        $deviceCount = Get-DeviceRuleCount -Headers $headers
        if ($deviceCount -eq $ruleCount) { break }
        Write-Host "Device has $deviceCount/$ruleCount rules; waiting for the remote cache ($attempt/8)..."
        Start-Sleep -Seconds 5
    }

    if ($deviceCount -ne $ruleCount) {
        throw "Device refresh did not reach the expected rule count ($deviceCount/$ruleCount). Run the same command again after the remote cache updates."
    }
    Write-Host "Device provider my_proxy refreshed: $deviceCount rules."
}
