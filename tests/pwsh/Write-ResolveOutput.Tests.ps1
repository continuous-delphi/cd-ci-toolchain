#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
<#
.SYNOPSIS
  Tests for Write-ResolveOutput in cd-ci-toolchain.ps1

.DESCRIPTION
  Covers: output lines produced for various entry shapes.

  The label column is 22 chars wide.  Value-presence assertions use array
  -match filtering so that a future padding tweak does not produce a cryptic
  string-mismatch failure.

  Context 1 - Entry with all optional fields populated (VER370):
    Verifies all seven lines are present -- ver, product_name, compilerVersion,
    package_version, bds_reg_version, registry_key_relpath, aliases -- and that
    the total line count is 7.

  Context 2 - Entry with a null optional field (VER150, bds_reg_version null):
    Verifies the bds_reg_version line is absent and total line count is 6.

  Context 3 - Aliases are comma-joined on one line:
    Verifies that multiple aliases appear as a comma-separated list.
#>

# PESTER 5 SCOPING RULES apply here -- see Resolve-DefaultDataFilePath.Tests.ps1
# for the canonical explanation.  Dot-source TestHelpers.ps1 and the script
# under test inside BeforeAll, not at the top level of the file.

Describe 'Write-ResolveOutput' {

  BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:scriptUnderTest = Get-ScriptUnderTestPath
    . $script:scriptUnderTest
  }

  Context 'Given an entry with all optional fields populated' {

    BeforeAll {
      $script:entry = [pscustomobject]@{
        ver                  = 'VER370'
        product_name         = 'Delphi 13 Florence'
        compilerVersion      = '37.0'
        package_version      = '370'
        bds_reg_version      = '37.0'
        registry_key_relpath = '\Software\Embarcadero\BDS\37.0'
        aliases              = @('VER370', 'Delphi13', 'Delphi 13 Florence', 'D13')
      }
      $script:output = Write-ResolveOutput -Entry $script:entry
    }

    It 'output includes a line with the ver value' {
      ($script:output -match 'ver\s+VER370') | Should -Not -BeNullOrEmpty
    }

    It 'output includes a line with the product_name value' {
      ($script:output -match 'product_name\s+Delphi 13 Florence') | Should -Not -BeNullOrEmpty
    }

    It 'output includes a line with the compilerVersion value' {
      ($script:output -match 'compilerVersion\s+37\.0') | Should -Not -BeNullOrEmpty
    }

    It 'output includes a line with the package_version value' {
      ($script:output -match 'package_version\s+370') | Should -Not -BeNullOrEmpty
    }

    It 'output includes a line with the bds_reg_version value' {
      ($script:output -match 'bds_reg_version\s+37\.0') | Should -Not -BeNullOrEmpty
    }

    It 'output includes a line with the registry_key_relpath value' {
      ($script:output -match 'registry_key_relpath\s+') | Should -Not -BeNullOrEmpty
    }

    It 'output includes a line with the aliases value' {
      ($script:output -match 'aliases\s+') | Should -Not -BeNullOrEmpty
    }

    It 'output has exactly seven lines' {
      $script:output | Should -HaveCount 7
    }

  }

  Context 'Given an entry with a null bds_reg_version' {

    BeforeAll {
      $script:entry = [pscustomobject]@{
        ver                  = 'VER150'
        product_name         = 'Delphi 7'
        compilerVersion      = '15.0'
        package_version      = '70'
        bds_reg_version      = $null
        registry_key_relpath = '\Software\Borland\Delphi\7.0'
        aliases              = @('VER150', 'Delphi7', 'D7')
      }
      $script:output = Write-ResolveOutput -Entry $script:entry
    }

    It 'output has exactly six lines' {
      $script:output | Should -HaveCount 6
    }

    It 'output does not include a bds_reg_version line' {
      ($script:output -match '^bds_reg_version\s') | Should -BeNullOrEmpty
    }

  }

  Context 'Given an entry with multiple aliases' {

    BeforeAll {
      $script:entry = [pscustomobject]@{
        ver                  = 'VER150'
        product_name         = 'Delphi 7'
        compilerVersion      = '15.0'
        package_version      = '70'
        bds_reg_version      = $null
        registry_key_relpath = '\Software\Borland\Delphi\7.0'
        aliases              = @('VER150', 'Delphi7', 'D7')
      }
      $script:output = Write-ResolveOutput -Entry $script:entry
    }

    It 'aliases line contains all aliases comma-separated' {
      ($script:output -match 'aliases\s+VER150, Delphi7, D7') | Should -Not -BeNullOrEmpty
    }

  }

}
