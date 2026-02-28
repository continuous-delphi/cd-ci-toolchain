#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
<#
.SYNOPSIS
  Subprocess integration tests for cd-ci-toolchain.ps1

.DESCRIPTION
  Invokes the script as a child process via Invoke-ToolProcess and validates
  exit codes, stdout, and stderr.  These tests cover the main execution block
  (the dispatch layer) which the dot-source guard deliberately skips when
  loading for unit tests.

  Each Context spawns exactly one subprocess and shares the result
  ($script:run) across Its.

  Contexts 1-4 supply -DataFile explicitly so they run without the submodule.
  Context 5 omits -DataFile to exercise the default path resolution branch;
  it requires cd-spec-delphi-compiler-versions to be initialized
  (git submodule update --init).

  Context 1 - No action switches + valid -DataFile:
    Default behavior is Version.  Validates exit 0 and all four stdout lines.

  Context 2 - -Version switch + valid -DataFile:
    Explicit switch produces the same output as the default.

  Context 3 - -DataFile path does not exist:
    Exit 3, no stdout, stderr contains "Data file not found".

  Context 4 - -DataFile contains malformed JSON:
    Exit 3, no stdout, stderr contains "Failed to parse JSON".

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
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-DataFile', $script:fixturePath)
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    # Exact match: the first line is the canonical format contract for the tool header.
    It 'first stdout line is the tool header' {
      $script:run.StdOut[0] | Should -Be 'cd-ci-toolchain 0.1.0'
    }

    It 'stdout includes a line with the dataVersion value' {
      ($script:run.StdOut -match 'dataVersion\s+0\.1\.0') | Should -Not -BeNullOrEmpty
    }

    It 'stdout includes a line with the schemaVersion value' {
      ($script:run.StdOut -match 'schemaVersion\s+1\.0\.0') | Should -Not -BeNullOrEmpty
    }

    It 'stdout includes a generated line' {
      ($script:run.StdOut -match '^generated\s') | Should -Not -BeNullOrEmpty
    }

    It 'stdout has exactly four lines' {
      $script:run.StdOut | Should -HaveCount 4
    }

  }

  Context 'Given -Version switch and a valid -DataFile' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Version', '-DataFile', $script:fixturePath)
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    It 'first stdout line is the tool header' {
      $script:run.StdOut[0] | Should -Be 'cd-ci-toolchain 0.1.0'
    }

    It 'stdout has exactly four lines' {
      $script:run.StdOut | Should -HaveCount 4
    }

  }

  Context 'Given -DataFile pointing to a path that does not exist' {

    BeforeAll {
      $missingPath = Join-Path ([System.IO.Path]::GetTempPath()) 'cd-ci-toolchain-integration-missing.json'
      $script:run  = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                        -Arguments @('-DataFile', $missingPath)
    }

    It 'exits with code 3' {
      $script:run.ExitCode | Should -Be 3
    }

    It 'produces no stdout' {
      $script:run.StdOut | Should -BeNullOrEmpty
    }

    It 'emits at least one stderr line containing "Data file not found"' {
      $script:run.StdErr | Should -Not -BeNullOrEmpty
      ($script:run.StdErr -join "`n") | Should -Match 'Data file not found'
    }

  }

  Context 'Given -DataFile pointing to a file with malformed JSON' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-DataFile', $script:badJsonPath)
    }

    It 'exits with code 3' {
      $script:run.ExitCode | Should -Be 3
    }

    It 'produces no stdout' {
      $script:run.StdOut | Should -BeNullOrEmpty
    }

    It 'emits at least one stderr line containing "Failed to parse JSON"' {
      $script:run.StdErr | Should -Not -BeNullOrEmpty
      ($script:run.StdErr -join "`n") | Should -Match 'Failed to parse JSON'
    }

  }

  # Requires: git submodule update --init
  Context 'Given no -DataFile and the submodule is initialized' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    It 'first stdout line is the tool header' {
      $script:run.StdOut[0] | Should -Be 'cd-ci-toolchain 0.1.0'
    }

    It 'stdout has exactly four lines' {
      $script:run.StdOut | Should -HaveCount 4
    }

  }

}
