# cd-ci-toolchain Tests

## Running the tests

From the `tests/` directory:

```powershell
./run-tests.ps1
```

This sets execution policy to `Bypass` for the process, imports Pester 5.7+,
and runs all test suites under `tests/pwsh/` with `Detailed` output.

Current results: **20 tests, 0 failures**

---

## Test suites

### Resolve-DefaultDataFilePath (3 tests)
- Returns a path ending with the canonical data file name
- Returns a path containing the spec submodule directory name
- Resolves to a path that exists on disk *(filesystem integration test)*

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

Pester 5 has strict scoping behavior that differs from Pester 4. Two rules
must be followed or tests will fail with `CommandNotFoundException` or silent
variable loss:

**Rule 1: Dot-source the script under test inside `BeforeAll`, not at the top
level of the file.**

Top-level dot-sourcing runs during the discovery phase. Functions loaded there
are not visible inside `It` blocks. The correct pattern:

```powershell
Describe 'MyFunction' {
  BeforeAll {
    $script:scriptUnderTest = Join-Path $PSScriptRoot '..' '..' 'source' 'pwsh' 'cd-ci-toolchain.ps1'
    $script:scriptUnderTest = [System.IO.Path]::GetFullPath($script:scriptUnderTest)
    . $script:scriptUnderTest
  }
  ...
}
```

**Rule 2: Re-resolve paths inside `BeforeAll` using `$PSScriptRoot` directly.**

Variables set in `TestHelpers.ps1` (such as `$MinFixturePath`) are available
during discovery but not during the run phase. Do not rely on them inside
`BeforeAll`. Re-derive any needed paths from `$PSScriptRoot`:

```powershell
BeforeAll {
  $script:fixturePath = Join-Path $PSScriptRoot 'fixtures' 'delphi-compiler-versions.min.json'
  $script:fixturePath = [System.IO.Path]::GetFullPath($script:fixturePath)
}
```

**Rule 3: Use `$script:` scope for all shared variables.**

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

- Use `Should -HaveCount` for collection length assertions
- For output line content, prefer `-match 'label\s+value'` over exact string
  matching so that padding changes do not produce cryptic failures
- Reserve exact `Should -Be` matching for format contracts (e.g. the tool
  header line) where the precise string is the thing being tested
- For negative presence assertions, anchor the pattern: `-match '^label\s'`
  to avoid false passes from partial word matches

### Submodule initialization

The filesystem existence test for `Resolve-DefaultDataFilePath` requires the
`cd-spec-delphi-compiler-versions` submodule to be initialized. If that test
fails with "path does not exist", run:

```powershell
git submodule update --init
```

from the repo root.
