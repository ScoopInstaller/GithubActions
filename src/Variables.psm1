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
# Location of bucket
$BUCKET_ROOT = $env:GITHUB_WORKSPACE
# Binaries from scoop. No need to rely on bucket specific binaries
$BINARIES_FOLDER = Join-Path $env:SCOOP_HOME 'bin'
$MANIFESTS_LOCATION = Join-Path $BUCKET_ROOT 'bucket'

$DEFAULT_EMAIL = '41898282+github-actions[bot]@users.noreply.github.com'

Export-ModuleMember -Variable EVENT, EVENT_TYPE, EVENT_RAW, REPOSITORY, BUCKET_ROOT, BINARIES_FOLDER, MANIFESTS_LOCATION, `
    NON_ZERO, DEFAULT_EMAIL
