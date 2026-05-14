# Shared log dump helper for delphi-inspect debug scripts.
# Dot-source this at the end of each debug.ps1 to write captured
# events to debug.log in the caller's folder.
#
# Usage (from a debug.ps1):
#   . "$PSScriptRoot\..\Write-CDDebugLog.ps1"
#
# $PSScriptRoot in the calling script resolves to the caller's folder,
# but inside a dot-sourced file $PSScriptRoot resolves to this file's
# folder. Use the caller's $MyInvocation to find the right location.

$callerDir = Split-Path -Parent $MyInvocation.PSCommandPath
$debugLogFile = Join-Path $callerDir 'debug.log'
$eventCount = (Get-CDLogEvents).Count

Get-CDLogEvents | ForEach-Object {
    '{0}  [{1}]  {2}' -f $_.timestampUtc, $_.level.ToUpperInvariant(), $_.message
} | Set-Content -Path $debugLogFile -Encoding utf8

Write-Host "Log written: $eventCount events to $debugLogFile"
