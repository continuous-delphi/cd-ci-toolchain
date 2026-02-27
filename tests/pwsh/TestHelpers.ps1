# TestHelpers.ps1
# Shared setup for all cd-ci-toolchain Pester tests.
#
# Dot-source this file at the top of each *.Tests.ps1:
#   . "$PSScriptRoot/TestHelpers.ps1"
#
# Provides:
#   $ScriptUnderTest  - absolute path to cd-ci-toolchain.ps1
#   $FixturesDir      - absolute path to tests/pwsh/fixtures/
#   $MinFixturePath   - absolute path to the minimal valid fixture JSON
#
# PESTER 5 SCOPING NOTE:
#   This file intentionally does NOT dot-source cd-ci-toolchain.ps1.
#   In Pester 5, dot-sourcing a script from a helper lands in the helper's
#   scope, not the test file's scope -- so functions would not be visible
#   to It blocks. The dot-source must happen inside a BeforeAll block in
#   the test file itself, using $PSScriptRoot to resolve the path directly.
#   See Resolve-DefaultDataFilePath.Tests.ps1 for the correct pattern.

$here           = $PSScriptRoot
$FixturesDir    = Join-Path $here 'fixtures'
$MinFixturePath = Join-Path $FixturesDir 'delphi-compiler-versions.min.json'

# Resolve the script under test relative to this file's location.
# Layout: tests/pwsh/ -> ../../source/pwsh/cd-ci-toolchain.ps1
# Use chained Join-Path calls rather than embedded separators so this
# works correctly on both Windows and non-Windows runners.
$ScriptUnderTest = Join-Path $here '..' '..' 'source' 'pwsh' 'cd-ci-toolchain.ps1'
$ScriptUnderTest = [System.IO.Path]::GetFullPath($ScriptUnderTest)
