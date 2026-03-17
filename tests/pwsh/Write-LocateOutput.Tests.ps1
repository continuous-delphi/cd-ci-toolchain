#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
<#
.SYNOPSIS
  Tests for Write-LocateOutput in delphi-inspect.ps1

.DESCRIPTION
  Covers: output produced for all three format modes.

  Context 1 - -Format text:
    Verifies verDefine, productName, and rootDir lines are present, and
    that the total line count is exactly 3.

  Context 2 - -Format json:
    Verifies the output is a single item that parses as valid JSON,
    ok is $true, command is 'locate', and result contains verDefine,
    productName, and rootDir with the expected values.

  Context 3 - -Format object (default):
    Verifies that one pscustomobject is emitted with the correct
    verDefine, productName, and rootDir properties.
#>

# PESTER 5 SCOPING RULES apply here -- see Resolve-DefaultDataFilePath.Tests.ps1
# for the canonical explanation.  Dot-source TestHelpers.ps1 and the script
# under test inside BeforeAll, not at the top level of the file.

Describe 'Write-LocateOutput' {

  BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:scriptUnderTest = Get-ScriptUnderTestPath
    . $script:scriptUnderTest

    $script:entry = [pscustomobject]@{
      verDefine   = 'VER370'
      productName = 'Delphi 13 Florence'
    }
    $script:rootDir = 'C:\Program Files (x86)\Embarcadero\Studio\24.0\'
  }

  Context 'Given -Format text' {

    BeforeAll {
      $script:output = Write-LocateOutput -Entry $script:entry -RootDir $script:rootDir -Format 'text'
    }

    It 'output includes a line with the verDefine value' {
      ($script:output -match 'verDefine\s+VER370') | Should -Not -BeNullOrEmpty
    }

    It 'output includes a line with the productName value' {
      ($script:output -match 'productName\s+Delphi 13 Florence') | Should -Not -BeNullOrEmpty
    }

    It 'output includes a line with the rootDir value' {
      ($script:output -match 'rootDir\s+') | Should -Not -BeNullOrEmpty
    }

    It 'output has exactly three lines' {
      $script:output | Should -HaveCount 3
    }

  }

  Context 'Given -Format json' {

    BeforeAll {
      $script:output = Write-LocateOutput -Entry $script:entry -RootDir $script:rootDir -ToolVersion '0.1.0' -Format 'json'
      $script:json   = $script:output | ConvertFrom-Json
    }

    It 'output is a single item' {
      $script:output | Should -HaveCount 1
    }

    It 'output parses as valid JSON' {
      { $script:output | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'ok is true' {
      $script:json.ok | Should -Be $true
    }

    It 'command is locate' {
      $script:json.command | Should -Be 'locate'
    }

    It 'result.verDefine matches the entry value' {
      $script:json.result.verDefine | Should -Be 'VER370'
    }

    It 'result.productName matches the entry value' {
      $script:json.result.productName | Should -Be 'Delphi 13 Florence'
    }

    It 'result.rootDir matches the supplied rootDir' {
      $script:json.result.rootDir | Should -Be $script:rootDir
    }

    It 'result does not contain unexpected properties' {
      $props = $script:json.result.PSObject.Properties.Name | Sort-Object
      $props | Should -Be @('productName', 'rootDir', 'verDefine')
    }

  }

  Context 'Given -Format object (default)' {

    BeforeAll {
      $script:output = Write-LocateOutput -Entry $script:entry -RootDir $script:rootDir
    }

    It 'emits one pscustomobject' {
      $script:output | Should -HaveCount 1
    }

    It 'has verDefine property with correct value' {
      $script:output.verDefine | Should -Be 'VER370'
    }

    It 'has productName property with correct value' {
      $script:output.productName | Should -Be 'Delphi 13 Florence'
    }

    It 'has rootDir property with correct value' {
      $script:output.rootDir | Should -Be $script:rootDir
    }

  }

}
