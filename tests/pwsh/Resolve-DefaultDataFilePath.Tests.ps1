#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
<#
.SYNOPSIS
  Tests for Resolve-DefaultDataFilePath in cd-ci-toolchain.ps1

.DESCRIPTION
  Covers: path construction from a given script location.

  Context 1 - Pure construction (no filesystem access):
    Verifies the returned path ends with the canonical data file name.
    Verifies the returned path contains the spec submodule directory name.

  Context 2 - Real repository layout:
    Verifies the resolved path exists on disk.
    Requires cd-spec-delphi-compiler-versions to be present as a submodule.
#>

. "$PSScriptRoot/TestHelpers.ps1"

# PESTER 5 SCOPING RULES - this file demonstrates the required pattern:
#
#   Rule 1: The dot-source of the script under test belongs inside BeforeAll,
#   not here at the top level. Top-level dot-sourcing loads functions into
#   discovery scope, which does not carry forward into It blocks.
#
#   Rule 2: $ScriptUnderTest from TestHelpers.ps1 is not available inside
#   BeforeAll. Re-resolve the path using $PSScriptRoot directly inside
#   BeforeAll and store in $script: scope for use across It blocks.

Describe 'Resolve-DefaultDataFilePath' {

  BeforeAll {
    $script:scriptUnderTest = Join-Path $PSScriptRoot '..' '..' 'source' 'pwsh' 'cd-ci-toolchain.ps1'
    $script:scriptUnderTest = [System.IO.Path]::GetFullPath($script:scriptUnderTest)
    . $script:scriptUnderTest
  }

  Context 'Given a script path in a standard source/pwsh layout' {

    It 'returns a path ending with the canonical data file name' {
      # Arrange
      $fakeScriptPath = Join-Path ([System.IO.Path]::GetTempPath()) `
                                  'repo\source\pwsh\cd-ci-toolchain.ps1'
      # Act
      $result = Resolve-DefaultDataFilePath -ScriptPath $fakeScriptPath

      # Assert
      $result | Should -Match ([regex]::Escape('delphi-compiler-versions.json'))
    }

    It 'returns a path containing the spec submodule directory name' {
      # Arrange
      $fakeScriptPath = Join-Path ([System.IO.Path]::GetTempPath()) `
                                  'repo\source\pwsh\cd-ci-toolchain.ps1'
      # Act
      $result = Resolve-DefaultDataFilePath -ScriptPath $fakeScriptPath

      # Assert
      $result | Should -Match ([regex]::Escape('cd-spec-delphi-compiler-versions'))
    }

  }

  Context 'Given the real repository layout' {

    It 'resolves to a path that exists on disk' {
      # Arrange
      # Use the actual script path so the traversal resolves against the real repo.
      # Requires cd-spec-delphi-compiler-versions to be present as a submodule.

      # Act
      $result = Resolve-DefaultDataFilePath -ScriptPath $script:scriptUnderTest
      $result = [System.IO.Path]::GetFullPath($result)

      # Assert
      $result | Should -Exist
    }

  }

}
