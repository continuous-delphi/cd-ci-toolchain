Import-Module ContinuousDelphi.Logger
Initialize-CDLogger -Source 'delphi-inspect' -OutputMode Silent -MinimumLevel Trace -CaptureOutput $true

& "$PSScriptRoot\..\..\..\source\delphi-inspect.ps1" `
    -Resolve `
    -Name 'Delphi 13' `
    -Format text

. "$PSScriptRoot\..\Write-CDDebugLog.ps1"
