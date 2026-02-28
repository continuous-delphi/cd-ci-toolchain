# TestHelpers.ps1
# Shared setup for all cd-ci-toolchain Pester tests.
#
# Dot-source this file at the top of each *.Tests.ps1:
#   . "$PSScriptRoot/TestHelpers.ps1"
#
# Provides (discovery scope — usable at top level of test files):
#   $ScriptUnderTest  - absolute path to cd-ci-toolchain.ps1
#   $FixturesDir      - absolute path to tests/pwsh/fixtures/
#   $MinFixturePath   - absolute path to the minimal valid fixture JSON
#
# Provides (run scope — usable inside BeforeAll / It blocks):
#   Get-ScriptUnderTestPath  - returns absolute path to cd-ci-toolchain.ps1
#   Get-MinFixturePath       - returns absolute path to the minimal fixture JSON
#
# PESTER 5 SCOPING NOTE:
#   Pester 5 isolates the run phase from the discovery phase entirely.
#   Both variables and functions defined by a top-level dot-source are
#   visible only during discovery and are invisible to BeforeAll and It
#   blocks.  Dot-source this file inside the Describe-level BeforeAll so
#   that its helper functions are available throughout the run phase:
#
#     Describe 'MyFunction' {
#       BeforeAll {
#         . "$PSScriptRoot/TestHelpers.ps1"
#         $script:scriptUnderTest = Get-ScriptUnderTestPath
#         . $script:scriptUnderTest
#       }
#     }
#
#   This file intentionally does NOT dot-source cd-ci-toolchain.ps1.
#   That dot-source must happen in the test file's own BeforeAll so that
#   the loaded functions land in the correct scope for It blocks.

$here           = $PSScriptRoot
$FixturesDir    = Join-Path $here 'fixtures'
$MinFixturePath = Join-Path $FixturesDir 'delphi-compiler-versions.min.json'

$ScriptUnderTest = Join-Path $here '..' '..' 'source' 'pwsh' 'cd-ci-toolchain.ps1'
$ScriptUnderTest = [System.IO.Path]::GetFullPath($ScriptUnderTest)

function Get-ScriptUnderTestPath {
  $path = Join-Path $PSScriptRoot '..' '..' 'source' 'pwsh' 'cd-ci-toolchain.ps1'
  return [System.IO.Path]::GetFullPath($path)
}

function Get-MinFixturePath {
  $path = Join-Path $PSScriptRoot 'fixtures' 'delphi-compiler-versions.min.json'
  return [System.IO.Path]::GetFullPath($path)
}
