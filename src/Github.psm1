Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module

function Invoke-GithubRequest {
    <#
    .SYNOPSIS
        Invoke authenticated github API request.
    .PARAMETER Query
        Query to be executed. `https://api/github.com/` is already included.
    .PARAMETER Method
        Method to be used with request.
    .PARAMETER Body
        Additional body to be send.
    .EXAMPLE
        Invoke-GithubRequest 'repos/User/Repo/pulls' -Method 'Post' -Body @{ 'body' = 'body' }
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String] $Query,
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method = 'Get',
        [Hashtable] $Body
    )

    $baseUrl = 'https://api.github.com'
    $parameters = @{
        'Headers' = @{
            # Authorization token is neeeded for posting comments and to increase limit of requests
            'Authorization' = "token $env:GITHUB_TOKEN"
        }
        'Method'  = $Method
        'Uri'     = "$baseUrl/$Query"
    }

    Write-Log 'Github Request' $parameters

    if ($Body) { $parameters.Add('Body', (ConvertTo-Json $Body -Depth 8 -Compress)) }

    Write-Log 'Request Body' $parameters.Body

    $env:GH_REQUEST_COUNTER = ([int] $env:GH_REQUEST_COUNTER) + 1

    return Invoke-WebRequest @parameters
}

function Add-Comment {
    <#
    .SYNOPSIS
        Add comment into specific issue / PR.
        https://developer.github.com/v3/issues/comments/
    .PARAMETER ID
        ID of issue / PR.
    .PARAMETER Message
        String or array of strings to be send as comment. Array will be joined with CRLF.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [Alias('Comment')]
        [String[]] $Message
    )

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/comments" -Method Post -Body @{ 'body' = ($Message -join "`r`n") }
}

function Get-AllChangedFilesInPR {
    <#
    .SYNOPSIS
        Get all changed files inside pull request.
        https://developer.github.com/v3/pulls/#list-pull-requests-files
    .PARAMETER ID
        ID of pull request.
    .PARAMETER Filter
        Return only files which are not 'removed'.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [Switch] $Filter
    )
    $filesno = ((Invoke-GithubRequest -Query "repos/$REPOSITORY/pulls/$ID").Content | ConvertFrom-Json).changed_files
    if ($filesno -le 100) {
        $files = (Invoke-GithubRequest -Query "repos/$REPOSITORY/pulls/$ID/files?per_page=$filesno").Content | ConvertFrom-Json
    } else {
        $files = @()
        for ($i = 1; $i -lt ($filesno / 100) + 1; $i++) {
            $files += (Invoke-GithubRequest -Query "repos/$REPOSITORY/pulls/$ID/files?per_page=100&page=$i").Content | ConvertFrom-Json
        }
    }
    if ($Filter) { $files = $files | Where-Object { $_.status -ne 'removed' } }

    return $files | Select-Object -Property filename, status
}

function New-Issue {
    <#
    .SYNOPSIS
        Create new issue in repository.
        https://developer.github.com/v3/issues/#create-an-issue
    .PARAMETER Title
        The title of issue.
    .PARAMETER Body
        Description of Issue. Array will be joined with CRLF.
    .PARAMETER Milestone
        Number of milestone to be associated with issue.
        Authenticated user needs push access to repository to be able to set milestone.
    .PARAMETER Label
        List of labels to be automatically added.
        Authenticated user needs push access to repository to be able to set label.
    .PARAMETER Assignee
        List of user logins to be automatically assigned.
        Authenticated user needs push access to repository to be able to set assignees.
    #>
    param(
        [Parameter(Mandatory)]
        [String] $Title,
        [String[]] $Body = '',
        [Int] $Milestone,
        [String[]] $Label = @(),
        [String[]] $Assignee = @()
    )

    $params = @{
        'title'     = $Title
        'body'      = ($Body -join "`r`n")
        'labels'    = $Label
        'assignees' = $Assignee
    }
    if ($Milestone) { $params.Add('milestone', $Milestone) }

    return Invoke-GithubRequest "repos/$REPOSITORY/issues" -Method 'Post' -Body $params
}

function Close-Issue {
    <#
    .SYNOPSIS
        Close issue / PR.
        https://developer.github.com/v3/issues/#edit-an-issue
    .PARAMETER ID
        ID of issue / PR to be closed.
    #>
    param([Parameter(Mandatory, ValueFromPipeline)][Int] $ID)

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID" -Method Patch -Body @{ 'state' = 'closed' }
}

function Add-Label {
    <#
    .SYNOPSIS
        Add label to issue / PR.
        https://developer.github.com/v3/issues/labels/#add-labels-to-an-issue
    .PARAMETER ID
        Id of issue / PR.
    .PARAMETER Label
        Label to be set.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()] # > Must contains at least one label
        [String[]] $Label
    )

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/labels" -Method Post -Body @{ 'labels' = $Label }
}

function Remove-Label {
    <#
    .SYNOPSIS
        Remove label from issue / PR.
        https://developer.github.com/v3/issues/labels/#remove-a-label-from-an-issue
    .PARAMETER ID
        ID of issue / PR.
    .PARAMETER Label
        Label to be removed.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [ValidateNotNullOrEmpty()]
        [String[]] $Label
    )

    $responses = New-Array
    # Get all labels on specific issue
    $issueLabels = (Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/labels" | Select-Object -ExpandProperty Content | ConvertFrom-Json).name

    foreach ($lab in $Label) {
        if ($issueLabels -contains $lab) {
            # https://developer.github.com/v3/issues/labels/#list-labels-on-an-issue
            Add-IntoArray $responses (Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/labels/$label" -Method Delete)
        }
    }

    return $responses
}

Export-ModuleMember -Function Invoke-GithubRequest, Add-Comment, Get-AllChangedFilesInPR, New-Issue, Close-Issue, `
    Add-Label, Remove-Label
