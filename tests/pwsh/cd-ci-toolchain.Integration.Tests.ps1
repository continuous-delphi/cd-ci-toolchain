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
    Default behavior is Version.  Validates exit 0, all four stdout lines, and clean stderr.

  Context 2 - -Version switch + valid -DataFile:
    Explicit switch produces the same output as the default.  Validates all four stdout
    lines and clean stderr, confirming the switch reaches the same dispatch branch.

  Context 3 - -DataFile path does not exist:
    Exit 3, no stdout, stderr contains "Data file not found".

  Context 4 - -DataFile contains malformed JSON:
    Exit 3, no stdout, stderr contains "Failed to parse JSON".

  Context 5 - No -DataFile, submodule present:
    Exercises the Resolve-DefaultDataFilePath branch of the dispatch block
    end-to-end.  Exit 0, tool header present.

  Contexts 6-10 cover the -Resolve dispatch branch.  All supply -DataFile
  explicitly using the resolve fixture (delphi-compiler-versions.resolve.json).

  Context 6 - -Resolve -Name VER150 (resolve by canonical VER):
    Exit 0, ver line present, product_name line present, clean stderr.

  Context 7 - -Resolve -Name D7 (resolve by short alias):
    Exit 0, ver line shows VER150.

  Context 8 - -Resolve -Name ver150 (case-insensitive):
    Exit 0, ver line shows VER150.

  Context 9 - -Resolve -Name for an unknown alias:
    Exit 4, no stdout, stderr contains "Alias not found".

  Context 10 - -Resolve without -Name:
    Exit 2, no stdout, stderr contains "-Resolve requires -Name".

  Context 11 - Multiple action switches (-Version -Resolve):
    Exit 2, no stdout, stderr contains "Specify only one action switch".
#>

Describe 'cd-ci-toolchain.ps1 (subprocess)' {

  BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:scriptPath         = Get-ScriptUnderTestPath
    $script:fixturePath        = Get-MinFixturePath
    $script:resolveFixturePath = Get-ResolveFixturePath

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

    It 'produces no stderr' {
      $script:run.StdErr | Should -BeNullOrEmpty
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

    It 'produces no stderr' {
      $script:run.StdErr | Should -BeNullOrEmpty
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

  Context 'Given -Resolve -Name VER150 and a valid -DataFile' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Resolve', '-Name', 'VER150', '-DataFile', $script:resolveFixturePath)
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    It 'stdout includes a ver line with the canonical VER value' {
      ($script:run.StdOut -match 'ver\s+VER150') | Should -Not -BeNullOrEmpty
    }

    It 'stdout includes a product_name line' {
      ($script:run.StdOut -match 'product_name\s+Delphi 7') | Should -Not -BeNullOrEmpty
    }

    It 'stdout includes a compilerVersion line' {
      ($script:run.StdOut -match 'compilerVersion\s+15\.0') | Should -Not -BeNullOrEmpty
    }

    It 'stdout includes an aliases line' {
      ($script:run.StdOut -match 'aliases\s+') | Should -Not -BeNullOrEmpty
    }

    It 'produces no stderr' {
      $script:run.StdErr | Should -BeNullOrEmpty
    }

  }

  Context 'Given -Resolve -Name D7 (short alias) and a valid -DataFile' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Resolve', '-Name', 'D7', '-DataFile', $script:resolveFixturePath)
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    It 'ver line resolves to the canonical VER150' {
      ($script:run.StdOut -match 'ver\s+VER150') | Should -Not -BeNullOrEmpty
    }

  }

  Context 'Given -Resolve -Name ver150 (lower-case input) and a valid -DataFile' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Resolve', '-Name', 'ver150', '-DataFile', $script:resolveFixturePath)
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    It 'ver line resolves to the canonical VER150' {
      ($script:run.StdOut -match 'ver\s+VER150') | Should -Not -BeNullOrEmpty
    }

  }

  Context 'Given -Resolve -Name for an alias not in the dataset' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Resolve', '-Name', 'DelphiX', '-DataFile', $script:resolveFixturePath)
    }

    It 'exits with code 4' {
      $script:run.ExitCode | Should -Be 4
    }

    It 'produces no stdout' {
      $script:run.StdOut | Should -BeNullOrEmpty
    }

    It 'emits at least one stderr line containing "Alias not found"' {
      $script:run.StdErr | Should -Not -BeNullOrEmpty
      ($script:run.StdErr -join "`n") | Should -Match 'Alias not found'
    }

  }

  Context 'Given -Resolve without -Name' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Resolve', '-DataFile', $script:resolveFixturePath)
    }

    It 'exits with code 2' {
      $script:run.ExitCode | Should -Be 2
    }

    It 'produces no stdout' {
      $script:run.StdOut | Should -BeNullOrEmpty
    }

    It 'emits at least one stderr line containing "-Resolve requires -Name"' {
      $script:run.StdErr | Should -Not -BeNullOrEmpty
      ($script:run.StdErr -join "`n") | Should -Match '-Resolve requires -Name'
    }

  }

  Context 'Given multiple action switches (-Version and -Resolve)' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Version', '-Resolve', '-DataFile', $script:fixturePath)
    }

    It 'exits with code 2' {
      $script:run.ExitCode | Should -Be 2
    }

    It 'produces no stdout' {
      $script:run.StdOut | Should -BeNullOrEmpty
    }

    It 'emits at least one stderr line containing "Specify only one action switch"' {
      $script:run.StdErr | Should -Not -BeNullOrEmpty
      ($script:run.StdErr -join "`n") | Should -Match 'Specify only one action switch'
    }

  }

}
