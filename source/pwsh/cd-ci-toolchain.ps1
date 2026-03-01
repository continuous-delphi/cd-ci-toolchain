<#
cd-ci-toolchain.ps1

Minimal V1:
- Loads the Delphi compiler versions dataset JSON.
- Prints tool version + dataset metadata.

ASCII-only.

USAGE
  pwsh ./source/cd-ci-toolchain.ps1
  pwsh ./source/cd-ci-toolchain.ps1 -Version
  pwsh ./source/cd-ci-toolchain.ps1 -Resolve -Name <alias>
  pwsh ./source/cd-ci-toolchain.ps1 -DataFile <path>

NOTES
  Default behavior is equivalent to -Version.
  This is intentional: future action switches will short-circuit -Version output.

  -Resolve looks up an alias or VER### string in the dataset (case-insensitive)
  and prints the canonical entry fields.  Exit 4 when the alias is not found.
#>

[CmdletBinding(DefaultParameterSetName='Version')]
param(
  [Parameter(ParameterSetName='Version')]
  [switch]$Version,

  [Parameter(ParameterSetName='Resolve', Mandatory=$true)]
  [switch]$Resolve,

  [Parameter(ParameterSetName='Resolve', Mandatory=$true, Position=0)]
  [string]$Name,

  [Parameter()]
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
  if (-not [string]::IsNullOrWhiteSpace($generated)) {
    Write-Output ("generated       {0}" -f $generated)
  }
}

function Resolve-VersionEntry {
  param(
    [string]$Name,
    [psobject]$Data
  )

  foreach ($entry in $Data.versions) {
    foreach ($alias in $entry.aliases) {
      if ([string]::Equals($alias, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $entry
      }
    }
  }
  return $null
}

function Write-ResolveOutput {
  param([psobject]$Entry)

  # Label column is 22 chars wide to accommodate 'registry_key_relpath' (20 chars).
  Write-Output ("ver                   {0}" -f $Entry.ver)
  Write-Output ("product_name          {0}" -f $Entry.product_name)
  Write-Output ("compilerVersion       {0}" -f $Entry.compilerVersion)
  if (-not [string]::IsNullOrWhiteSpace($Entry.package_version)) {
    Write-Output ("package_version       {0}" -f $Entry.package_version)
  }
  if (-not [string]::IsNullOrWhiteSpace($Entry.bds_reg_version)) {
    Write-Output ("bds_reg_version       {0}" -f $Entry.bds_reg_version)
  }
  if (-not [string]::IsNullOrWhiteSpace($Entry.registry_key_relpath)) {
    Write-Output ("registry_key_relpath  {0}" -f $Entry.registry_key_relpath)
  }
  if ($Entry.aliases -and $Entry.aliases.Count -gt 0) {
    Write-Output ("aliases               {0}" -f ($Entry.aliases -join ', '))
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
  # Mutual exclusion and mandatory -Name are enforced by parameter sets.
  $doVersion = $Version
  if (-not $doVersion -and -not $Resolve) { $doVersion = $true }

  if ([string]::IsNullOrWhiteSpace($DataFile)) {
    $DataFile = Resolve-DefaultDataFilePath -ScriptPath $scriptPath
  }

  # NOTE: dataset errors exit here directly (exit 3) rather than propagating
  # to the outer catch.  As more exit codes are added, consider extracting the
  # dispatch block into an Invoke-Main function that returns an exit code, with
  # a single exit at the script's top level.  That eliminates scattered exit
  # calls and makes the code table easy to audit in one place.
  try {
    $data = Import-JsonData -Path $DataFile
  } catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 3
  }

  if ($doVersion) {
    Write-VersionInfo -ToolVersion $ToolVersion -Data $data
    exit 0
  }

  if ($Resolve) {
    $entry = Resolve-VersionEntry -Name $Name -Data $data
    if ($null -eq $entry) {
      Write-Error "Alias not found: $Name" -ErrorAction Continue
      exit 4
    }
    Write-ResolveOutput -Entry $entry
    exit 0
  }

  exit 0
} catch {
  # Print a single-line error for CI log readability.
  Write-Error $_.Exception.Message -ErrorAction Continue
  exit 1
}