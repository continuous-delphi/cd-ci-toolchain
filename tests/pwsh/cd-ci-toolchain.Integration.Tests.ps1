#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
<#
.SYNOPSIS
  Subprocess integration tests for cd-ci-toolchain.ps1

.DESCRIPTION
  Invokes the script as a child pwsh process and validates exit codes and
  stdout.  These tests cover the main execution block (the dispatch layer)
  which the dot-source guard deliberately skips when loading for unit tests.

  Each Context spawns exactly one subprocess and shares the result across
  Its via $script:output and $script:exitCode.

  Contexts 1-4 supply -DataFile explicitly so they run without the submodule.
  Context 5 omits -DataFile to exercise the default path resolution branch;
  it requires cd-spec-delphi-compiler-versions to be initialized
  (git submodule update --init).

  Known gap: the README documents exit code 3 for "Dataset missing or
  unreadable" but the current catch block exits 1 for all errors.  The
  tests below assert the actual behavior (exit 1).

  Context 1 - No action switches + valid -DataFile:
    Default behavior is Version.  Validates exit 0 and all four stdout lines.

  Context 2 - -Version switch + valid -DataFile:
    Explicit switch produces the same output as the default.

  Context 3 - -DataFile path does not exist:
    Exit 1, no stdout.

  Context 4 - -DataFile contains malformed JSON:
    Exit 1, no stdout.

  Context 5 - No -DataFile, submodule present:
    Exercises the Resolve-DefaultDataFilePath branch of the dispatch block
    end-to-end.  Exit 0, tool header present.
#>

Describe 'cd-ci-toolchain.ps1 (subprocess)' {

  BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:scriptPath  = Get-ScriptUnderTestPath
    $script:fixturePath = Get-MinFixturePath

    $script:badJsonPath = Join-Path ([System.IO.Path]::GetTempPath()) 'cd-ci-toolchain-integration-bad.json'
    Set-Content -LiteralPath $script:badJsonPath -Value '{ bad json' -Encoding UTF8NoBOM
  }

  AfterAll {
    if (Test-Path -LiteralPath $script:badJsonPath) {
      Remove-Item -LiteralPath $script:badJsonPath -Force
    }
  }

  Context 'Given no action switches and a valid -DataFile' {

    BeforeAll {
      $script:output   = & pwsh -NoProfile -NonInteractive -File $script:scriptPath `
                                -DataFile $script:fixturePath
      $script:exitCode = $LASTEXITCODE
    }

    It 'exits with code 0' {
      $script:exitCode | Should -Be 0
    }

    # Exact match: the first line is the canonical format contract for the tool header.
    It 'first stdout line is the tool header' {
      $script:output[0] | Should -Be 'cd-ci-toolchain 0.1.0'
    }

    It 'stdout includes a line with the dataVersion value' {
      ($script:output -match 'dataVersion\s+0\.1\.0') | Should -Not -BeNullOrEmpty
    }

    It 'stdout includes a line with the schemaVersion value' {
      ($script:output -match 'schemaVersion\s+1\.0\.0') | Should -Not -BeNullOrEmpty
    }

    It 'stdout includes a generated line' {
      ($script:output -match '^generated\s') | Should -Not -BeNullOrEmpty
    }

    It 'stdout has exactly four lines' {
      $script:output | Should -HaveCount 4
    }

  }

  Context 'Given -Version switch and a valid -DataFile' {

    BeforeAll {
      $script:output   = & pwsh -NoProfile -NonInteractive -File $script:scriptPath `
                                -Version -DataFile $script:fixturePath
      $script:exitCode = $LASTEXITCODE
    }

    It 'exits with code 0' {
      $script:exitCode | Should -Be 0
    }

    It 'first stdout line is the tool header' {
      $script:output[0] | Should -Be 'cd-ci-toolchain 0.1.0'
    }

    It 'stdout has exactly four lines' {
      $script:output | Should -HaveCount 4
    }

  }

  Context 'Given -DataFile pointing to a path that does not exist' {

    BeforeAll {
      $missingPath     = Join-Path ([System.IO.Path]::GetTempPath()) 'cd-ci-toolchain-integration-missing.json'
      $script:output   = & pwsh -NoProfile -NonInteractive -File $script:scriptPath `
                                -DataFile $missingPath 2>$null
      $script:exitCode = $LASTEXITCODE
    }

    It 'exits with code 1' {
      $script:exitCode | Should -Be 1
    }

    It 'produces no stdout' {
      $script:output | Should -BeNullOrEmpty
    }

  }

  Context 'Given -DataFile pointing to a file with malformed JSON' {

    BeforeAll {
      $script:output   = & pwsh -NoProfile -NonInteractive -File $script:scriptPath `
                                -DataFile $script:badJsonPath 2>$null
      $script:exitCode = $LASTEXITCODE
    }

    It 'exits with code 1' {
      $script:exitCode | Should -Be 1
    }

    It 'produces no stdout' {
      $script:output | Should -BeNullOrEmpty
    }

  }

  # Requires: git submodule update --init
  Context 'Given no -DataFile and the submodule is initialized' {

    BeforeAll {
      $script:output   = & pwsh -NoProfile -NonInteractive -File $script:scriptPath
      $script:exitCode = $LASTEXITCODE
    }

    It 'exits with code 0' {
      $script:exitCode | Should -Be 0
    }

    It 'first stdout line is the tool header' {
      $script:output[0] | Should -Be 'cd-ci-toolchain 0.1.0'
    }

    It 'stdout has exactly four lines' {
      $script:output | Should -HaveCount 4
    }

  }

}
