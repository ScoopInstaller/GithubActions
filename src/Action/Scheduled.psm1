Join-Path $PSScriptRoot '..\Helpers.psm1' | Import-Module

function Initialize-Scheduled {
    <#
    .SYNOPSIS
        Excavator alternative. Based on schedule execute of auto-pr binary.
    #>
    Write-Log 'Scheduled initialized'

    if ($env:GITHUB_REF_NAME) {
        $_BRANCH = $env:GITHUB_REF_NAME
    } else {
        $_BRANCH = 'master'
    }

    $params = @{
        'Dir'          = $MANIFESTS_LOCATION
        'Upstream'     = "${REPOSITORY}:${_BRANCH}"
        'OriginBranch' = $_BRANCH
        'Push'         = $true
        'SkipUpdated'  = ($env:SKIP_UPDATED -eq '1')
    }
    if ($env:SPECIAL_SNOWFLAKES) { $params.Add('SpecialSnowflakes', ($env:SPECIAL_SNOWFLAKES -split ',')) }
    if ($env:THROW_ERROR -eq '1') { $params.Add('ThrowError', $true) }

    # Respect any already added GH Tokens
    if (-not $env:SCOOP_GH_TOKEN) {
        $env:SCOOP_GH_TOKEN = $env:GITHUB_TOKEN
    }

    & (Join-Path $BINARIES_FOLDER 'auto-pr.ps1') @params
    # TODO: Post some comment?? Or other way how to publish logs for non collaborators.

    Write-Log 'Scheduled finished'
}

Export-ModuleMember -Function Initialize-Scheduled
