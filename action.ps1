# Set Global Preference
$Global:ErrorActionPreference = 'Continue'
$Global:VerbosePreference = 'Continue'

# Import all modules
Join-Path $PSScriptRoot 'src' | Get-ChildItem -File | Select-Object -ExpandProperty Fullname | Import-Module

Install-Scoop

Test-NestedBucket
Initialize-NeededConfiguration

git config --get user.email
Write-Log 'Importing all modules'
# Load all scoop's modules.
# Dot sourcing needs to be done on highest scope possible to propagate into lower scopes
Get-ChildItem (Join-Path $env:SCOOP_HOME 'lib') '*.ps1' | ForEach-Object { . $_.FullName }

Write-Log 'FULL EVENT' $EVENT_RAW

Invoke-Action

Write-Log 'Number of Github Requests' $env:GH_REQUEST_COUNTER

if ($env:NON_ZERO_EXIT) { exit $NON_ZERO }
