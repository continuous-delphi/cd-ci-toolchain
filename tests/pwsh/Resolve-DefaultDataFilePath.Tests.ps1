#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
<#
.SYNOPSIS
  Tests for Resolve-DefaultDataFilePath in delphi-inspect.ps1

.DESCRIPTION
  Covers: path resolution priority and fallback behaviour.

  Context 1 - Neither submodule nor sibling file present:
    Verifies the returned path ends with the canonical data file name and
    contains the spec submodule directory name (i.e. falls back to the
    canonical submodule path for a meaningful error downstream).

  Context 2 - Sibling data file present, no submodule:
    Verifies that a delphi-compiler-versions.json placed next to the script
    is returned when the submodule path does not exist.

  Context 3 - Both submodule and sibling data file present:
    Verifies that the sibling file takes priority over the submodule path.

  Context 4 - Real repository layout:
    Verifies the resolved path exists on disk.
    Requires delphi-compiler-versions to be present as a submodule.
#>

# PESTER 5 SCOPING RULES - this file demonstrates the required pattern:
#
#   Rule 1: Dot-source both TestHelpers.ps1 and the script under test inside
#   BeforeAll, not at the top level of the file.  Pester 5 isolates the run
#   phase from the discovery phase entirely -- top-level dot-sources reach
#   discovery scope only and are invisible to BeforeAll and It blocks.
#
#   Rule 2: Use $script: scope for all variables shared across It blocks.

Describe 'Resolve-DefaultDataFilePath' {

  BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:scriptUnderTest = Get-ScriptUnderTestPath
    . $script:scriptUnderTest
  }

  Context 'Given neither the submodule path nor a sibling data file exists' {

    BeforeAll {
      $fakeRepo              = Join-Path ([System.IO.Path]::GetTempPath()) 'delphi-inspect-test-repo'
      $fakeScriptDir         = Join-Path $fakeRepo 'source'
      $script:fakeScriptPath = Join-Path $fakeScriptDir 'delphi-inspect.ps1'
      # Create a placeholder script file only -- no data files anywhere.
      $null = New-Item -ItemType Directory -Path $fakeScriptDir -Force
      $null = New-Item -ItemType File -Path $script:fakeScriptPath -Force
    }

    AfterAll {
      if (Test-Path -LiteralPath $script:fakeScriptPath) {
        Remove-Item -LiteralPath $script:fakeScriptPath -Force
      }
    }

    It 'returns a path ending with the canonical data file name' {
      $result = Resolve-DefaultDataFilePath -ScriptPath $script:fakeScriptPath
      $result | Should -Match ([regex]::Escape('delphi-compiler-versions.json'))
    }

    It 'returns the submodule path (canonical fallback for error reporting)' {
      $result = Resolve-DefaultDataFilePath -ScriptPath $script:fakeScriptPath
      $result | Should -Match ([regex]::Escape('submodules'))
    }

  }

  Context 'Given only a sibling data file exists next to the script' {

    BeforeAll {
      $fakeRepo              = Join-Path ([System.IO.Path]::GetTempPath()) 'delphi-inspect-test-sibling'
      $fakeScriptDir         = Join-Path $fakeRepo 'source'
      $script:fakeScriptPath = Join-Path $fakeScriptDir 'delphi-inspect.ps1'
      $script:siblingPath    = Join-Path $fakeScriptDir 'delphi-compiler-versions.json'
      $null = New-Item -ItemType Directory -Path $fakeScriptDir -Force
      $null = New-Item -ItemType File -Path $script:fakeScriptPath -Force
      $null = New-Item -ItemType File -Path $script:siblingPath -Force
    }

    AfterAll {
      foreach ($p in @($script:fakeScriptPath, $script:siblingPath)) {
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
      }
    }

    It 'returns the sibling file path' {
      $result = Resolve-DefaultDataFilePath -ScriptPath $script:fakeScriptPath
      $result | Should -Be $script:siblingPath
    }

  }

  Context 'Given both a submodule data file and a sibling data file exist' {

    BeforeAll {
      $fakeRepo              = Join-Path ([System.IO.Path]::GetTempPath()) 'delphi-inspect-test-both'
      $fakeScriptDir         = Join-Path $fakeRepo 'source'
      $script:fakeScriptPath = Join-Path $fakeScriptDir 'delphi-inspect.ps1'
      $script:siblingPath    = Join-Path $fakeScriptDir 'delphi-compiler-versions.json'
      $submoduleDataDir      = Join-Path (Join-Path (Join-Path $fakeRepo 'submodules') 'delphi-compiler-versions') 'data'
      $script:submodulePath  = Join-Path $submoduleDataDir 'delphi-compiler-versions.json'
      $null = New-Item -ItemType Directory -Path $fakeScriptDir -Force
      $null = New-Item -ItemType Directory -Path $submoduleDataDir -Force
      $null = New-Item -ItemType File -Path $script:fakeScriptPath -Force
      $null = New-Item -ItemType File -Path $script:siblingPath -Force
      $null = New-Item -ItemType File -Path $script:submodulePath -Force
    }

    AfterAll {
      foreach ($p in @($script:fakeScriptPath, $script:siblingPath, $script:submodulePath)) {
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
      }
    }

    It 'returns the sibling path (sibling takes priority)' {
      $result = Resolve-DefaultDataFilePath -ScriptPath $script:fakeScriptPath
      $result | Should -Be $script:siblingPath
    }

  }

  Context 'Given the real repository layout' {

    It 'resolves to a path that exists on disk' {
      # Arrange
      # Use the actual script path so the traversal resolves against the real repo.
      # Requires delphi-compiler-versions to be present as a submodule.

      # Act
      $result = Resolve-DefaultDataFilePath -ScriptPath $script:scriptUnderTest
      $result = [System.IO.Path]::GetFullPath($result)

      # Assert
      $result | Should -Exist
    }

  }

}
