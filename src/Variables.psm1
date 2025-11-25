function Initialize-PreferenceVariable {
    <#
    .SYNOPSIS
        Initializes PowerShell preference variables based on environment variables or default values.
    #>

    $DefaultPreferences = [ordered]@{
        # Set ErrorActionPreference first and prevent it from being overridden by the environment variable.
        ErrorActionPreference = @{ Value = 'Continue'; IgnoreEnv = $true }
        DebugPreference       = @{ Value = 'SilentlyContinue' }
        InformationPreference = @{ Value = 'SilentlyContinue' }
        VerbosePreference     = @{ Value = 'SilentlyContinue' }
        WarningPreference     = @{ Value = 'Continue' }
    }

    foreach ($Name in $DefaultPreferences.Keys) {
        $Preference = $DefaultPreferences[$Name]
        $Value = $Preference.Value

        $EnvValue = Get-Item "Env:$Name" -ErrorAction Ignore | Select-Object -ExpandProperty Value

        if ((-not $Preference.IgnoreEnv) -and ($EnvValue)) {
            $Value = $EnvValue
        }

        # Use built-in output functions instead of Write-Log here to avoid dependency issues
        Write-Host "Setting $Name to $Value ..."

        Set-Variable -Name $Name -Value $Value -Scope Global
    }
}

# Initialize PowerShell Preference Variables
Initialize-PreferenceVariable

# Environment
$env:SCOOP = Join-Path $env:USERPROFILE 'SCOOP'
$env:SCOOP_HOME = Join-Path $env:SCOOP 'apps\scoop\current'
$env:SCOOP_GLOBAL = Join-Path $env:SystemDrive 'SCOOP'
$env:SCOOP_DEBUG = 1

[System.Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')
[System.Environment]::SetEnvironmentVariable('SCOOP_HOME', $env:SCOOP_HOME, 'User')
[System.Environment]::SetEnvironmentVariable('SCOOP_GLOBAL', $env:SCOOP_GLOBAL, 'Machine')
[System.Environment]::SetEnvironmentVariable('SCOOP_DEBUG', $env:SCOOP_DEBUG, 'Machine')

$env:GH_REQUEST_COUNTER = 0
$NON_ZERO = 258

# Convert actual API response to object
$EVENT = Get-Content $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json
# Compressed Event
$EVENT_RAW = ConvertTo-Json $EVENT -Depth 100 -Compress
# Event type for automatic handler detection
$EVENT_TYPE = $env:GITHUB_EVENT_NAME

# user/repo format
$REPOSITORY = $env:GITHUB_REPOSITORY
# Github Action job name & run ID
$JOB = $env:GITHUB_JOB
$RUN_ID = $env:GITHUB_RUN_ID
# Location of bucket
$BUCKET_ROOT = $env:GITHUB_WORKSPACE
# Binaries from scoop. No need to rely on bucket specific binaries
$BINARIES_FOLDER = Join-Path $env:SCOOP_HOME 'bin'
# Manifests JSON Schema and location
$MANIFESTS_SCHEMA = Join-Path $env:SCOOP_HOME 'schema.json'
$MANIFESTS_LOCATION = Join-Path $BUCKET_ROOT 'bucket'

$DEFAULT_EMAIL = '41898282+github-actions[bot]@users.noreply.github.com'

Export-ModuleMember -Variable EVENT, EVENT_RAW, EVENT_TYPE, `
    REPOSITORY, JOB, RUN_ID, `
    BUCKET_ROOT, BINARIES_FOLDER, `
    MANIFESTS_SCHEMA, MANIFESTS_LOCATION, NON_ZERO, DEFAULT_EMAIL
