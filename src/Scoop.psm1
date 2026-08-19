Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module

function Install-Scoop {
    <#
    .SYNOPSIS
        Install scoop using new installer.
    #>
    Write-LogInfo 'Installing scoop'
    Invoke-RestMethod 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1' | Invoke-Expression
    if ($env:SCOOP_REPO) {
        Write-LogInfo "Switching to repository: ${env:SCOOP_REPO}"
        scoop config scoop_repo $env:SCOOP_REPO
        $needUpdate = $true
    }
    if ($env:SCOOP_BRANCH) {
        Write-LogInfo "Switching to branch: ${env:SCOOP_BRANCH}"
        scoop config scoop_branch $env:SCOOP_BRANCH
        $needUpdate = $true
    }
    if ($needUpdate) {
        scoop update
    }
}

Export-ModuleMember -Function Install-Scoop
