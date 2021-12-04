Join-Path $PSScriptRoot '..\Helpers.psm1' | Import-Module

function Initialize-Scheduled {
    <#
    .SYNOPSIS
        Excavator alternative. Based on schedule execute of auto-pr binary.
    #>
    Write-Log 'Scheduled initialized'

    if ($env:GITHUB_BRANCH) {
        $_BRANCH = $env:GITHUB_BRANCH
    } else {
        $_BRANCH = 'master'
    }

    $params = @{
        'Dir'         = $MANIFESTS_LOCATION
        'Upstream'    = "${REPOSITORY}:${_BRANCH}"
        'Push'        = $true
        'SkipUpdated' = [bool] $env:SKIP_UPDATED
    }
    if ($env:SPECIAL_SNOWFLAKES) { $params.Add('SpecialSnowflakes', ($env:SPECIAL_SNOWFLAKES -split ',')) }

    $env:SCOOP_CHECKVER_TOKEN = $env:GITHUB_TOKEN

    & (Join-Path $BINARIES_FOLDER 'auto-pr.ps1') @params
    # TODO: Post some comment?? Or other way how to publish logs for non collaborators.

    Write-Log 'Scheduled finished'
}

Export-ModuleMember -Function Initialize-Scheduled
