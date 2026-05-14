@echo off
setlocal
pushd "%~dp0"

::
:: Update the Write-CDHostLog snippet from the delphi-logger repo.
:: Source: https://github.com/continuous-delphi/delphi-logger
::
pwsh -NoProfile -File "C:\code\delphi-logger\tools\Inject-CDHostLog.ps1" -TargetFile "%~dp0..\source\delphi-inspect.ps1"

set "EXITCODE=%ERRORLEVEL%"
pause
popd
endlocal & exit /b %EXITCODE%
