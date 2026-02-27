<#
cd-ci-toolchain.ps1

Minimal V1:
- Loads the Delphi compiler versions dataset JSON.
- Prints tool version + dataset metadata.

ASCII-only.

USAGE
  pwsh ./source/cd-ci-toolchain.ps1
  pwsh ./source/cd-ci-toolchain.ps1 -Version
  pwsh ./source/cd-ci-toolchain.ps1 -DataFile <path>

NOTES
  Default behavior is equivalent to -Version.
  This is intentional: future action switches will short-circuit -Version output.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)]
  [switch]$Version,

  [Parameter(Mandatory=$false)]
  [string]$DataFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Tool version (bump per Continuous Delphi versioning policy for tooling)
$ToolVersion = '0.1.0'

function Resolve-DefaultDataFilePath {
  param([string]$ScriptPath)

  $scriptDir = Split-Path -Parent $ScriptPath

  # Prefer the submodule layout:
  #   ../cd-spec-delphi-compiler-versions/data/delphi-compiler-versions.json
  # Use Join-Path to remain path-separator-safe if invoked on non-Windows runners.
  $repoRoot    = Join-Path $scriptDir '..' '..'
  $specRoot    = Join-Path $repoRoot 'submodules' 'cd-spec-delphi-compiler-versions'
  $dataDir     = Join-Path $specRoot 'data'
  $defaultPath = Join-Path $dataDir 'delphi-compiler-versions.json'

  return $defaultPath
}

function Import-JsonData {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Data file not found: $Path"
  }

  # Use -Raw to avoid array-of-lines behavior
  $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  try {
    return $text | ConvertFrom-Json
  } catch {
    throw "Failed to parse JSON in data file: $Path. $($_.Exception.Message)"
  }
}

function Write-VersionInfo {
  param(
    [string]$ToolVersion,
    [psobject]$Data
  )

  $schemaVersion = $Data.schemaVersion
  $dataVersion = $Data.dataVersion

  # generated date lives under meta.generated_utc_date in our dataset
  $generated = $null
  if ($null -ne $Data.meta -and $null -ne $Data.meta.generated_utc_date) {
    $generated = $Data.meta.generated_utc_date
  }

  Write-Output ("cd-ci-toolchain {0}" -f $ToolVersion)
  Write-Output ("dataVersion     {0}" -f $dataVersion)
  Write-Output ("schemaVersion   {0}" -f $schemaVersion)
  if ($null -ne $generated -and $generated -ne '') {
    Write-Output ("generated       {0}" -f $generated)
  }
}

# Guard: skip top-level execution when the script is dot-sourced for testing.
# Pester dot-sources the file to import functions; $MyInvocation.InvocationName
# is '.' in that case. Direct execution always sets it to the script path.
if ($MyInvocation.InvocationName -eq '.') { return }

try {
  $scriptPath = $PSCommandPath
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    throw "Cannot resolve script path. Run as a file, not dot-sourced."
  }

  # Default behavior: if no action switches specified, treat as -Version.
  # This is intentional: future action switches will short-circuit when present.
  $doVersion = $Version
  if (-not $doVersion) { $doVersion = $true }

  if ([string]::IsNullOrWhiteSpace($DataFile)) {
    $DataFile = Resolve-DefaultDataFilePath -ScriptPath $scriptPath
  }

  $data = Import-JsonData -Path $DataFile

  if ($doVersion) {
    Write-VersionInfo -ToolVersion $ToolVersion -Data $data
    exit 0
  }

  # Future switches will go here.
  exit 0
} catch {
  # Print a single-line error for CI log readability.
  Write-Error $_.Exception.Message
  exit 1
}