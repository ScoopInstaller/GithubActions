Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module
Join-Path $PSScriptRoot 'Action' | Get-ChildItem -Filter '*.psm1' | Select-Object -ExpandProperty Fullname | Import-Module

function Invoke-Action {
    <#
    .SYNOPSIS
        Invoke specific action handler.
    #>
    Write-LogInfo -Summary 'GitHub API rate limit status (start)' -Message (Get-RateLimit -Core | Format-List)

    switch ($GITHUB_EVENT_TYPE) {
        'pull_request' { Initialize-PR }
        'issue_comment' { Initialize-PR }
        'schedule' { Initialize-Scheduled }
        'workflow_dispatch' { Initialize-Scheduled }
        'repository_dispatch' { Initialize-Scheduled }
        'issues' { Initialize-Issue }
        default { Write-LogInfo 'Not supported event type' }
    }

    Write-LogInfo -Summary 'GitHub API rate limit status (end)' -Message (Get-RateLimit -Core | Format-List)
}

Export-ModuleMember -Function Invoke-Action
