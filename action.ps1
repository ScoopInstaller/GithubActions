# Set Global Preference
$ProgressPreference = 'SilentlyContinue'
# FIXME(chawyehsu): see https://github.com/ScoopInstaller/GithubActions/pull/86#discussion_r3795404713
$Global:ErrorActionPreference = 'Continue'

# Import all modules
Join-Path $PSScriptRoot 'src' | Get-ChildItem -File | Select-Object -ExpandProperty Fullname | Import-Module

Write-Host '::group::Setup Scoop'
Install-Scoop
Test-NestedBucket
Initialize-NeededConfiguration
Write-Host '::endgroup::'

Write-Verbose 'Importing all modules'
# Load all scoop's modules.
# Dot sourcing needs to be done on highest scope possible to propagate into lower scopes
Get-ChildItem (Join-Path $env:SCOOP_HOME 'lib') '*.ps1' | ForEach-Object { . $_.FullName }

Invoke-Action

Write-LogInfo "${env:GH_REQUEST_COUNTER} GitHub requests used"

if ($env:NON_ZERO_EXIT) { exit $NON_ZERO }
