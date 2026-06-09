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

switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { $arch = "amd64" }
    "ARM64" { $arch = "arm64" }
    "x86" { $arch = "386" }
    default { throw "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}

New-Item -ItemType Directory -Path $workDir -Force | Out-Null
Set-Location $workDir

$exe = Join-Path (Get-Location) "cfst.exe"
if (-not (Test-Path $exe)) {
    $asset = "cfst_windows_$arch.zip"
    $archive = Join-Path (Get-Location) $asset
    $url = "https://github.com/$repo/releases/latest/download/$asset"
    Write-Host "Downloading official CloudflareSpeedTest release:"
    Write-Host "  $url"
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
    Expand-Archive -Path $archive -DestinationPath (Get-Location) -Force
}

if (-not $CfstArgs -or $CfstArgs.Count -eq 0) {
    $CfstArgs = @("-tl", $tl, "-dn", $dn, "-o", $output)
}

Write-Host "Running: $exe $($CfstArgs -join ' ')"
& $exe @CfstArgs

Write-Host ""
Write-Host "Result file: $(Join-Path (Get-Location) $output)"
Write-Host "Upload this file to your VPS, then choose menu 11 -> import local speed test result."
