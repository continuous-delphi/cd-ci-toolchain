# run-tests.ps1
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
Import-Module Pester -MinimumVersion 5.7.0 -Force
Invoke-Pester ./pwsh -Output Detailed