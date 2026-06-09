[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $CfstArgs
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = "XIU2/CloudflareSpeedTest"
$workDir = if ($env:CFST_DIR) { $env:CFST_DIR } else { Join-Path (Get-Location) "cfst-local" }
$tl = if ($env:CFST_TL) { $env:CFST_TL } else { "200" }
$dn = if ($env:CFST_DN) { $env:CFST_DN } else { "20" }
$output = if ($env:CFST_OUTPUT) { $env:CFST_OUTPUT } else { "result.csv" }

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin -and $env:CFST_ALLOW_ADMIN -ne "1") {
    throw "Refusing to run as Administrator. Run as a normal local user, or set CFST_ALLOW_ADMIN=1 to override."
}

if ([Net.ServicePointManager]::SecurityProtocol.ToString() -notmatch "Tls12") {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { $arch = "amd64" }
    "ARM64" { $arch = "arm64" }
    "x86" { $arch = "386" }
    default { throw "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}

function Invoke-Download {
    param(
        [Parameter(Mandatory = $true)] [string] $Uri,
        [Parameter(Mandatory = $true)] [string] $OutFile
    )

    for ($i = 1; $i -le 3; $i++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
            return
        } catch {
            if ($i -eq 3) { throw }
            Start-Sleep -Seconds 2
        }
    }
}

New-Item -ItemType Directory -Path $workDir -Force | Out-Null
Set-Location $workDir

$exe = Join-Path (Get-Location) "cfst.exe"
if (-not (Test-Path $exe)) {
    $asset = "cfst_windows_$arch.zip"
    $url = "https://github.com/$repo/releases/latest/download/$asset"
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cfst-" + [guid]::NewGuid().ToString("N"))
    $extractDir = Join-Path $tempRoot "extract"
    $archive = Join-Path $tempRoot $asset

    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    try {
        Write-Host "Downloading official CloudflareSpeedTest release:"
        Write-Host "  $url"
        Invoke-Download -Uri $url -OutFile $archive
        Get-FileHash -Algorithm SHA256 -Path $archive | Format-List

        Expand-Archive -Path $archive -DestinationPath $extractDir -Force
        $found = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter "cfst.exe" | Select-Object -First 1
        if (-not $found) {
            throw "cfst.exe not found in downloaded archive."
        }

        Copy-Item -LiteralPath $found.FullName -Destination $exe -Force
    } finally {
        if (Test-Path $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}
Get-FileHash -Algorithm SHA256 -Path $exe | Format-List

if (-not $CfstArgs -or $CfstArgs.Count -eq 0) {
    $CfstArgs = @("-tl", $tl, "-dn", $dn, "-o", $output)
}

Write-Host "Running: $exe $($CfstArgs -join ' ')"
& $exe @CfstArgs

Write-Host ""
Write-Host "Result file: $(Join-Path (Get-Location) $output)"
Write-Host "Upload this file to your VPS, then choose menu 11 -> import local speed test result."
