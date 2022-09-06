Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module

function Install-Scoop {
    <#
    .SYNOPSIS
        Install scoop using new installer.
    #>
    Write-Log 'Installing scoop'
    $f = Join-Path $env:USERPROFILE 'install.ps1'
    Invoke-WebRequest 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1' -UseBasicParsing -OutFile $f
    & $f -RunAsAdmin
    if ($env:SCOOP_BRANCH) {
        Write-Log "Switching to branch: ${env:SCOOP_BRANCH}"
        scoop config SCOOP_BRANCH $env:SCOOP_BRANCH
        scoop update
    } else {
        scoop update
    }
}

Export-ModuleMember -Function Install-Scoop
