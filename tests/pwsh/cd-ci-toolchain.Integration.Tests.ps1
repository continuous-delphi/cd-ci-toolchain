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

  Context 7b - -Resolve D7 (positional -Name):
    Exit 0, ver line shows VER150.  Verifies Position=0 on -Name.

  Context 8 - -Resolve -Name ver150 (case-insensitive):
    Exit 0, ver line shows VER150.

  Context 9 - -Resolve -Name for an unknown alias:
    Exit 4, no stdout, stderr contains "Alias not found".

  Context 10 - -Resolve without -Name:
    Exit 1 (PowerShell parameter binding rejects the invocation before the
    script body runs), no stdout, stderr references the mandatory Name parameter.

  Context 11 - Multiple action switches (-Version -Resolve):
    Exit 1 (PowerShell parameter binding rejects the invocation before the
    script body runs), no stdout, stderr references parameter set resolution.

  Context 12 - -Resolve -Name VER370 (all fields in text mode):
    All seven output lines present (ver, product_name, compilerVersion,
    package_version, bds_reg_version, registry_key_relpath, aliases).
    Fills the text-mode all-fields gap left by Contexts 6-8 which use VER150.

  Context 13 - -Version -Format json and a valid -DataFile:
    Exit 0, stdout is a single JSON envelope with ok=true, command='version',
    and result containing schemaVersion, dataVersion, generated_utc_date.
    Clean stderr.

  Context 14 - -Resolve -Name VER150 -Format json and a valid -DataFile:
    Exit 0, stdout is a single JSON envelope with ok=true, command='resolve',
    result.ver=VER150, result.bds_reg_version=null (present as null, unlike
    text mode which omits the line), and result.aliases containing 'D7'.
    Clean stderr.

  Context 15 - -DataFile pointing to a missing path -Format json:
    Exit 3, stdout is a JSON error envelope (ok=false, error.code=3,
    error.message contains 'Data file not found').  Clean stderr.

  Context 16 - -Resolve for an unknown alias -Format json:
    Exit 4, stdout is a JSON error envelope (ok=false, error.code=4,
    error.message contains 'Alias not found').  Clean stderr.

  Context 17 - -Format yaml (invalid ValidateSet value):
    Exit 1 (PowerShell parameter binder rejects 'yaml' before the script body
    runs).  No stdout.  Stderr present.
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

  Context 'Given -Resolve D7 (positional -Name) and a valid -DataFile' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Resolve', 'D7', '-DataFile', $script:resolveFixturePath)
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

    It 'exits with code 1 (PowerShell parameter binding failure)' {
      $script:run.ExitCode | Should -Be 1
    }

    It 'produces no stdout' {
      $script:run.StdOut | Should -BeNullOrEmpty
    }

    It 'emits stderr referencing the mandatory Name parameter' {
      $script:run.StdErr | Should -Not -BeNullOrEmpty
      ($script:run.StdErr -join "`n") | Should -Match 'Name'
    }

  }

  Context 'Given multiple action switches (-Version and -Resolve)' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Version', '-Resolve', '-DataFile', $script:fixturePath)
    }

    It 'exits with code 1 (PowerShell parameter binding failure)' {
      $script:run.ExitCode | Should -Be 1
    }

    It 'produces no stdout' {
      $script:run.StdOut | Should -BeNullOrEmpty
    }

    It 'emits stderr referencing parameter set resolution failure' {
      $script:run.StdErr | Should -Not -BeNullOrEmpty
      ($script:run.StdErr -join "`n") | Should -Match 'parameter set'
    }

  }

  Context 'Given -Resolve -Name VER370 and a valid -DataFile (all fields)' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Resolve', '-Name', 'VER370', '-DataFile', $script:resolveFixturePath)
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    It 'stdout has exactly seven lines' {
      $script:run.StdOut | Should -HaveCount 7
    }

    It 'stdout includes a bds_reg_version line' {
      ($script:run.StdOut -match 'bds_reg_version\s+37\.0') | Should -Not -BeNullOrEmpty
    }

    It 'produces no stderr' {
      $script:run.StdErr | Should -BeNullOrEmpty
    }

  }

  Context 'Given -Version -Format json and a valid -DataFile' {

    BeforeAll {
      $script:run  = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                        -Arguments @('-Version', '-Format', 'json', '-DataFile', $script:fixturePath)
      $script:json = ($script:run.StdOut -join "`n") | ConvertFrom-Json
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    It 'stdout parses as valid JSON' {
      { ($script:run.StdOut -join "`n") | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'JSON ok is true and command is version' {
      $script:json.ok      | Should -Be $true
      $script:json.command | Should -Be 'version'
    }

    It 'JSON result.schemaVersion is present' {
      ($script:run.StdOut -join "`n") | Should -Match 'schemaVersion'
    }

    It 'JSON result.dataVersion is present' {
      ($script:run.StdOut -join "`n") | Should -Match 'dataVersion'
    }

    It 'JSON result.generated_utc_date is not null' {
      $script:json.result.generated_utc_date | Should -Not -BeNullOrEmpty
    }

    It 'produces no stderr' {
      $script:run.StdErr | Should -BeNullOrEmpty
    }

  }

  Context 'Given -Resolve -Name VER150 -Format json and a valid -DataFile' {

    BeforeAll {
      $script:run  = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                        -Arguments @('-Resolve', '-Name', 'VER150', '-Format', 'json', '-DataFile', $script:resolveFixturePath)
      $script:json = ($script:run.StdOut -join "`n") | ConvertFrom-Json
    }

    It 'exits with code 0' {
      $script:run.ExitCode | Should -Be 0
    }

    It 'stdout parses as valid JSON' {
      { ($script:run.StdOut -join "`n") | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'JSON ok is true and command is resolve' {
      $script:json.ok      | Should -Be $true
      $script:json.command | Should -Be 'resolve'
    }

    It 'JSON result.ver is VER150' {
      $script:json.result.ver | Should -Be 'VER150'
    }

    It 'JSON result.bds_reg_version is null' {
      $script:json.result.bds_reg_version | Should -Be $null
    }

    It 'JSON result.aliases contains D7' {
      $script:json.result.aliases | Should -Contain 'D7'
    }

    It 'produces no stderr' {
      $script:run.StdErr | Should -BeNullOrEmpty
    }

  }

  Context 'Given -DataFile pointing to a missing path -Format json' {

    BeforeAll {
      $missingPath = Join-Path ([System.IO.Path]::GetTempPath()) 'cd-ci-toolchain-integration-missing-json.json'
      $script:run  = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                        -Arguments @('-Format', 'json', '-DataFile', $missingPath)
      $script:json = ($script:run.StdOut -join "`n") | ConvertFrom-Json
    }

    It 'exits with code 3' {
      $script:run.ExitCode | Should -Be 3
    }

    It 'stdout parses as valid JSON' {
      { ($script:run.StdOut -join "`n") | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'JSON ok is false' {
      $script:json.ok | Should -Be $false
    }

    It 'JSON error.code is 3' {
      $script:json.error.code | Should -Be 3
    }

    It 'JSON error.message contains "Data file not found"' {
      $script:json.error.message | Should -Match 'Data file not found'
    }

    It 'produces no stderr' {
      $script:run.StdErr | Should -BeNullOrEmpty
    }

  }

  Context 'Given -Resolve for an unknown alias -Format json' {

    BeforeAll {
      $script:run  = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                        -Arguments @('-Resolve', '-Name', 'DelphiX', '-Format', 'json', '-DataFile', $script:resolveFixturePath)
      $script:json = ($script:run.StdOut -join "`n") | ConvertFrom-Json
    }

    It 'exits with code 4' {
      $script:run.ExitCode | Should -Be 4
    }

    It 'stdout parses as valid JSON' {
      { ($script:run.StdOut -join "`n") | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'JSON ok is false' {
      $script:json.ok | Should -Be $false
    }

    It 'JSON error.code is 4' {
      $script:json.error.code | Should -Be 4
    }

    It 'JSON error.message contains "Alias not found"' {
      $script:json.error.message | Should -Match 'Alias not found'
    }

    It 'produces no stderr' {
      $script:run.StdErr | Should -BeNullOrEmpty
    }

  }

  Context 'Given -Format yaml (invalid ValidateSet value)' {

    BeforeAll {
      $script:run = Invoke-ToolProcess -ScriptPath $script:scriptPath `
                                       -Arguments @('-Version', '-Format', 'yaml', '-DataFile', $script:fixturePath)
    }

    It 'exits with code 1 (PowerShell parameter binding failure)' {
      $script:run.ExitCode | Should -Be 1
    }

    It 'produces no stdout' {
      $script:run.StdOut | Should -BeNullOrEmpty
    }

    It 'emits stderr' {
      $script:run.StdErr | Should -Not -BeNullOrEmpty
    }

  }

}
