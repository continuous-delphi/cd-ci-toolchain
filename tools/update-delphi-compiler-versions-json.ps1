#Requires -Version 7.4
<#
update-delphi-compiler-versions-json.ps1

Replaces the embedded Delphi compiler versions JSON block inside
delphi-inspect.ps1 with the current dataset from the
delphi-compiler-versions submodule.

Intended to be run from the repo root, or from the tools/ directory.
No parameters -- path resolution is relative to this script's location.

EXIT CODES
  0  Success -- script updated and written
  1  Source data file not found
  2  Target script file not found
  3  BEGIN tag not found in target script
  4  END tag not found in target script (BEGIN was found)
  5  END tag found before BEGIN tag
  6  Failed to write updated script
  7  Source data file is not valid JSON
  8  Required variable '$EmbeddedData' not found in target script

TAGS (must be present in delphi-inspect.ps1)
  # BEGIN-DELPHI-COMPILER-VERSIONS-JSON
  # END-DELPHI-COMPILER-VERSIONS-JSON

The entire content between the tags (inclusive of the tag lines themselves)
is replaced. The here-string assignment wrapping the JSON is regenerated
on each run -- only the tag comment lines must be manually maintained in
the target script.

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BeginTag = '# BEGIN-DELPHI-COMPILER-VERSIONS-JSON'
$EndTag   = '# END-DELPHI-COMPILER-VERSIONS-JSON'

# Resolve paths relative to this script's location (tools/)
$toolsDir  = Split-Path -Parent $PSCommandPath
$repoRoot  = Split-Path -Parent $toolsDir

$dataFile  = Join-Path $repoRoot 'submodules' 'delphi-compiler-versions' 'data' 'delphi-compiler-versions.json'
$scriptFile = Join-Path $repoRoot 'source' 'delphi-inspect.ps1'

# --- Validate inputs -------------------------------------------------------

if (-not (Test-Path -LiteralPath $dataFile)) {
  Write-Error "Data file not found: $dataFile" -ErrorAction Continue
  exit 1
}

if (-not (Test-Path -LiteralPath $scriptFile)) {
  Write-Error "Target script not found: $scriptFile" -ErrorAction Continue
  exit 2
}

# --- Load files ------------------------------------------------------------

$jsonContent   = Get-Content -LiteralPath $dataFile -Raw -Encoding UTF8NoBOM
$scriptContent = Get-Content -LiteralPath $scriptFile -Raw -Encoding UTF8NoBOM

# --- Parse JSON (validates before any mutation) ----------------------------
# Parsing here ensures malformed JSON is caught before the script is touched.
# $dataVersion is captured now and reused in the report section below.

try {
  $dataObj     = $jsonContent | ConvertFrom-Json
  $dataVersion = $dataObj.dataVersion
} catch {
  Write-Error "Source data file is not valid JSON: $($_.Exception.Message)" -ErrorAction Continue
  exit 7
}

# --- Locate tags -----------------------------------------------------------

$beginIndex = $scriptContent.IndexOf($BeginTag)
if ($beginIndex -lt 0) {
  Write-Error "BEGIN tag not found in script: $BeginTag" -ErrorAction Continue
  exit 3
}

$endIndex = $scriptContent.IndexOf($EndTag)
if ($endIndex -lt 0) {
  Write-Error "END tag not found in script: $EndTag" -ErrorAction Continue
  exit 4
}

if ($endIndex -le $beginIndex) {
  Write-Error "END tag appears at or before BEGIN tag in script. File may be corrupt." -ErrorAction Continue
  exit 5
}

# --- Validate target script structure --------------------------------------
# The variable name written into the replacement block is hardcoded below.
# Verify it exists in the target script so a rename does not silently produce
# a dead assignment that the script never reads.

if ($scriptContent.IndexOf('$EmbeddedData') -lt 0) {
  Write-Error "Required variable '`$EmbeddedData' not found in target script. Has it been renamed?" -ErrorAction Continue
  exit 8
}

# --- Build replacement block -----------------------------------------------
# Normalise line ending to CRLF to match PowerShell script convention on Windows.
# The here-string uses @' '@ (single-quoted) so the JSON is treated as a literal
# string with no variable expansion -- safe for any JSON content.

$newline = "`r`n"

$jsonTrimmed = $jsonContent.TrimEnd()

$replacement = $BeginTag + $newline +
               '$EmbeddedData = @''' + $newline +
               $jsonTrimmed + $newline +
               '''@' + $newline +
               $EndTag

# --- Splice ----------------------------------------------------------------
# Replace from the start of the BEGIN tag line through to the end of the END
# tag line.  endIndex points to the start of $EndTag; advance past it.

$endOfEndTag = $endIndex + $EndTag.Length

$before = $scriptContent.Substring(0, $beginIndex)
$after  = $scriptContent.Substring($endOfEndTag)

# Normalise the entire output to CRLF before writing.  $before and $after carry
# whatever line endings the file had on disk; the replacement block is already
# CRLF.  Normalising the whole string eliminates mixed line endings at the
# splice boundaries if the file was somehow checked out with LF despite
# .gitattributes enforcing CRLF for .ps1 files.
$updatedContent = ($before + $replacement + $after).Replace("`r`n", "`n").Replace("`n", "`r`n")

# --- Write -----------------------------------------------------------------

try {
  # UTF8NoBOM, consistent with the rest of the repo
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($scriptFile, $updatedContent, $utf8NoBom)
} catch {
  Write-Error "Failed to write updated script: $($_.Exception.Message)" -ErrorAction Continue
  exit 6
}

# --- Report ----------------------------------------------------------------

Write-Output "Updated: $scriptFile"
Write-Output "Embedded dataVersion: $dataVersion"
exit 0
