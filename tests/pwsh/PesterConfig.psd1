# PesterConfiguration for cd-ci-toolchain PowerShell tests.
# Run from the repository root with: Invoke-Pester -Configuration (Import-PowerShellDataFile ./tests/pwsh/PesterConfig.psd1)
# Or simply: Invoke-Pester ./tests/pwsh
#
# Requires: Pester 5.7+

@{
  Run = @{
    Path = './tests/pwsh'
  }
  Output = @{
    Verbosity = 'Detailed'
  }
  TestResult = @{
    Enabled      = $true
    OutputPath   = './tests/pwsh/results/pester-results.xml'
    OutputFormat = 'NUnitXml'
  }
  CodeCoverage = @{
    Enabled    = $false
  }
}