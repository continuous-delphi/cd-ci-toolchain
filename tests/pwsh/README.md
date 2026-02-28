# cd-ci-toolchain Tests

## Running the tests

### To run all tests

From the repository root (or any directory -- the script is location-independent):

```powershell
./tests/run-tests.ps1
```

This sets execution policy to `Bypass` for the process, imports Pester 5.7+,
loads `PesterConfig.psd1`, and runs all test suites under `tests/pwsh/` with
`Detailed` output and NUnit XML results written to `tests/pwsh/results/`.

---

### To run a single suite during development

From the root directory:

```powershell
Invoke-Pester ./tests/pwsh/Write-VersionInfo.Tests.ps1 -Output Detailed
```

---

## Test suites

### Resolve-DefaultDataFilePath (3 tests)

- Returns a path ending with the canonical data file name
- Returns a path containing the spec submodule directory name
- Resolves to a path that exists on disk
  *(requires submodule -- see [Submodule initialization](#submodule-initialization))*

### Import-JsonData (6 tests)

- Returns parsed object with correct schemaVersion
- Returns parsed object with correct dataVersion
- Returns parsed object with correct meta.generated_utc_date
- Returns parsed object with empty compilers list
- Throws with "Data file not found" for a missing path
- Throws with "Failed to parse JSON" for malformed JSON

### Write-VersionInfo (11 tests)

- First output line exactly matches tool header format contract
- Output includes a line with the dataVersion value
- Output includes a line with the schemaVersion value
- Output includes a generated line when meta.generated_utc_date is set
- Output has exactly four lines when all fields populated
- Output has exactly three lines when meta is null
- Output does not include a generated line when meta is null
- Output has exactly three lines when generated_utc_date is empty
- Output does not include a generated line when generated_utc_date is empty
- Output has exactly three lines when generated_utc_date is whitespace-only
- Output does not include a generated line when generated_utc_date is whitespace-only

### cd-ci-toolchain.ps1 subprocess integration (18 tests)

Invokes the script as a child process via `Invoke-ToolProcess`; validates exit
codes, stdout, and stderr.  Covers the dispatch block that the dot-source guard
skips during unit tests.

- No action switches + valid `-DataFile`: exit 0, tool header, all four output lines
- `-Version` switch + valid `-DataFile`: exit 0, tool header, four output lines
- `-DataFile` pointing to a missing path: exit 3, no stdout, stderr contains "Data file not found"
- `-DataFile` pointing to malformed JSON: exit 3, no stdout, stderr contains "Failed to parse JSON"
- No `-DataFile`, submodule initialized: exit 0, tool header, four output lines
  *(requires submodule -- see [Submodule initialization](#submodule-initialization))*

---

## Standards for new PowerShell test files

### File header

Every test file must begin with:

```powershell
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
<#
.SYNOPSIS
  Tests for <FunctionName> in cd-ci-toolchain.ps1

.DESCRIPTION
  Covers: <brief description of what is tested>

  Context 1 - <description>:
    <what is verified>
  ...
#>
```

### Pester 5 scoping rules

Pester 5 isolates the run phase (BeforeAll, It, AfterAll) from the discovery
phase entirely -- both variables and functions defined by a top-level dot-source
are invisible to `BeforeAll` and `It` blocks.  Two rules follow from this:

**Rule 1: Dot-source `TestHelpers.ps1` and the script under test inside the
Describe-level `BeforeAll`, not at the top level of the file.**

The Describe-level `BeforeAll` runs once before all nested blocks, so anything
dot-sourced there is available to every `Context` and `It` within that
`Describe`.  The correct pattern:

```powershell
Describe 'MyFunction' {
  BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:scriptUnderTest = Get-ScriptUnderTestPath
    . $script:scriptUnderTest

    $script:fixturePath = Get-MinFixturePath
  }
  ...
}
```

`Get-ScriptUnderTestPath` and `Get-MinFixturePath` are helper functions
defined in `TestHelpers.ps1` that return fully-resolved absolute paths.
Using functions rather than the plain `$ScriptUnderTest` / `$MinFixturePath`
variables lets all path logic stay in one place.

**Rule 2: Use `$script:` scope for all variables shared across `It` blocks.**

Variables assigned in `BeforeAll` must use the `$script:` prefix to be
visible inside `It` blocks within the same `Describe` or `Context`.

### Dot-source guard in cd-ci-toolchain.ps1

The script under test contains a dot-source guard at the top:

```powershell
if ($MyInvocation.InvocationName -eq '.') { return }
```

When the script is dot-sourced (as in tests), this guard fires and the script
body does not execute -- only the function definitions are loaded into scope.
This is intentional and is what makes the script safely testable without
triggering live API calls or file I/O at load time.

Do not remove this guard.

### Encoding

All test files and fixture files must be UTF-8 without BOM.

When writing temp files in tests, use `-Encoding UTF8NoBOM` with
`Set-Content`, not `-Encoding UTF8`. On some .NET versions `UTF8` emits a
BOM which can cause unexpected behavior in parsers and APIs.

```powershell
# Correct
Set-Content -LiteralPath $path -Value $content -Encoding UTF8NoBOM

# Avoid -- may emit BOM
Set-Content -LiteralPath $path -Value $content -Encoding UTF8
```

### Fixture files

Shared fixture files live in `tests/pwsh/fixtures/`. The minimal fixture
`delphi-compiler-versions.min.json` contains a structurally valid but
minimal dataset suitable for most parsing tests.

Ephemeral files created for specific test cases (malformed JSON, missing
paths, etc.) should use `[System.IO.Path]::GetTempPath()` and must be
cleaned up in `AfterAll`.

### Assertion style

- Use `Should -HaveCount` for collection length assertions; use `Should -Not -BeNullOrEmpty`
  to assert a collection is non-empty
- For output line content, prefer `-match 'label\s+value'` over exact string
  matching so that padding changes do not produce cryptic failures
- Reserve exact `Should -Be` matching for format contracts (e.g. the tool
  header line) where the precise string is the thing being tested
- For negative presence assertions, anchor the pattern: `-match '^label\s'`
  to avoid false passes from partial word matches

### Submodule initialization

Two tests require the `cd-spec-delphi-compiler-versions` submodule to be
initialized: the filesystem existence test in `Resolve-DefaultDataFilePath`
and the no-`-DataFile` context in the subprocess integration suite.  If
either fails with "path does not exist", run:

```powershell
git submodule update --init
```

from the repo root.
