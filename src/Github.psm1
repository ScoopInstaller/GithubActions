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
            'Authorization' = "Bearer $env:GITHUB_TOKEN"
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

function Invoke-GithubGraphQL {
    <#
    .SYNOPSIS
        Invoke authenticated GitHub GraphQL API request.
    .PARAMETER Query
        GraphQL query string.
    .PARAMETER Variables
        Variables to be used in the query.
    .EXAMPLE
        Invoke-GithubGraphQL -Query 'query { viewer { login } }'
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String] $Query,
        [Hashtable] $Variables
    )

    $body = @{
        'query' = $Query
    }
    if ($Variables) {
        $body.Add('variables', (ConvertTo-Json $Variables -Depth 8 -Compress))
    }

    $parameters = @{
        'Headers' = @{
            'Authorization' = "Bearer $env:GITHUB_TOKEN"
            'Accept' = 'application/vnd.github.v3+json'
        }
        'Method'  = 'Post'
        'Uri'     = 'https://api.github.com/graphql'
        'Body'    = (ConvertTo-Json $body -Depth 8 -Compress)
    }

    Write-Log 'GraphQL Request' @{ 'query' = $Query; 'variables' = $Variables }
    $env:GH_REQUEST_COUNTER = ([int] $env:GH_REQUEST_COUNTER) + 1

    $response = Invoke-WebRequest @parameters
    $content = $response.Content | ConvertFrom-Json

    if ($content.errors) {
        throw "GraphQL errors: $($content.errors | ConvertTo-Json -Compress)"
    }

    return $content.data
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
    .PARAMETER AppendLogLink
        If set, link to current job log will be appended to comment.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [Alias('Comment')]
        [String[]] $Message,
        [switch] $AppendLogLink
    )

    if ($AppendLogLink -and $Message) {
        $Message += "`r`n[_Check the full log for details._]($(Get-LogURL -UseCache:$true))"
    }

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/comments" -Method Post -Body @{ 'body' = ($Message -join "`r`n") }
}

function Get-AllChangedFilesInPR {
    <#
    .SYNOPSIS
        Get all changed files inside pull request using GraphQL API.
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

    $owner, $name = $REPOSITORY -split '/'

    $query = @'
query ($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      files(first: 100, after: $cursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          path
          status
        }
      }
    }
  }
}
'@

    $files = @()
    $cursor = $null

    do {
        $variables = @{
            owner = $owner
            name = $name
            number = $ID
            cursor = $cursor
        }

        $data = Invoke-GithubGraphQL -Query $query -Variables $variables
        $pageData = $data.repository.pullRequest.files

        $files += $pageData.nodes | ForEach-Object {
            [PSCustomObject]@{
                filename = $_.path
                status = $_.status
            }
        }

        $cursor = $pageData.pageInfo.endCursor
        $hasNextPage = $pageData.pageInfo.hasNextPage
    } while ($hasNextPage)

    if ($Filter) { $files = $files | Where-Object { $_.status -ne 'removed' } }

    return $files
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

function Get-RepositoryInfoAndPRs {
    <#
    .SYNOPSIS
        Get repository default branch, branch protection status, and PRs in a single GraphQL query.
    .PARAMETER PRTitle
        PR title to filter.
    #>
    param(
        [String] $PRTitle
    )

    $owner, $name = $REPOSITORY -split '/'

    $query = @'
query ($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef {
      name
    }
    branchProtectionRules(first: 10) {
      nodes {
        pattern
        isAdminEnforced
      }
    }
    pullRequests(states: OPEN, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        number
        title
        body
        baseRefName
      }
    }
  }
}
'@
    $variables = @{
        owner = $owner
        name = $name
    }

    $data = Invoke-GithubGraphQL -Query $query -Variables $variables
    $repo = $data.repository

    $defaultBranch = $repo.defaultBranchRef.name

    $result = @{
        defaultBranch = $defaultBranch
    }

    # Check if default branch is protected by matching protection rules
    $branchProtectionRules = $repo.branchProtectionRules.nodes
    $isProtected = $false
    foreach ($rule in $branchProtectionRules) {
        if ($defaultBranch -like $rule.pattern) {
            $isProtected = $true
            break
        }
    }
    $result.isProtected = $isProtected
    $defaultBranchPRs = $repo.pullRequests.nodes | Where-Object { $_.baseRefName -eq $defaultBranch }

    if ($PRTitle) {
        $result.prs = $defaultBranchPRs | Where-Object { $_.title -eq $PRTitle }
    } else {
        $result.prs = $defaultBranchPRs
    }

    return $result
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

function Get-RateLimit {
    <#
    .SYNOPSIS
        Retrieves the current GitHub API rate limit status.
        Returns the rate limit information as a deserialized JSON object.
    .PARAMETER Core
        If specified, returns only the core rate limit information.
    #>
    param(
        [Switch] $Core
    )

    $rateLimit = $null

    try {
        $response = Invoke-GithubRequest -Query 'rate_limit'

        $rateLimit = $response.Content | ConvertFrom-Json
    } catch {
        Write-Log -Summary "Failed to retrieve rate limit information.`n Exception occurred: $($_.Exception.Message)"
    }

    if ($Core -and $rateLimit -and $rateLimit.resources -and $rateLimit.resources.core) {
        $rateLimit = $rateLimit.resources.core
    }

    return $rateLimit
}

function Get-JobID {
    <#
    .SYNOPSIS
        Gets the ID for the current GitHub Actions job.
        Caches the result to avoid redundant API calls.
    .PARAMETER UseCache
        Whether to use the cached job ID if available.
    .PARAMETER RetryCount
        Number of times to retry fetching the job ID if the initial attempt fails. Default is 3.
    .PARAMETER RetryDelaySeconds
        Number of seconds to wait between retries when fetching the job ID. Default is 3.
    #>
    param(
        [Parameter(Mandatory)]
        [Switch] $UseCache,
        [ValidateRange(1, 10)]
        [Int] $RetryCount = 3,
        [ValidateRange(1, 30)]
        [Int] $RetryDelaySeconds = 3
    )

    if ($UseCache -and $script:JOB_ID) {
        return $script:JOB_ID
    }

    $jobId = $null

    for ($i = 0; $i -lt $RetryCount; ++$i) {
        try {
            $response = Invoke-GithubRequest -Query "repos/$REPOSITORY/actions/runs/$RUN_ID/jobs"

            $jobs = ($response.Content | ConvertFrom-Json).jobs

            $jobId = $jobs | Where-Object { $_.name -eq $JOB } | Select-Object -ExpandProperty id -First 1

            if ($jobId) {
                # Cache the job ID
                $script:JOB_ID = $jobId

                break
            }
        } catch {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    return $jobId
}

function Get-LogURL {
    <#
    .SYNOPSIS
        Gets the URL for the current GitHub Actions job log.
        If the job ID cannot be retrieved, this command returns the URL for the workflow run instead.
    .PARAMETER UseCache
        Whether to use the cached job ID if available.
    .PARAMETER RetryCount
        Number of times to retry fetching the job ID if the initial attempt fails. Default is 3.
    .PARAMETER RetryDelaySeconds
        Number of seconds to wait between retries when fetching the job ID. Default is 3.
    #>
    param(
        [Parameter(Mandatory)]
        [Switch] $UseCache,
        [ValidateRange(1, 10)]
        [Int] $RetryCount = 3,
        [ValidateRange(1, 30)]
        [Int] $RetryDelaySeconds = 3
    )

    $logURL = "https://github.com/$REPOSITORY/actions/runs/$RUN_ID"

    $job_id = Get-JobID -UseCache:$UseCache -RetryCount $RetryCount -RetryDelaySeconds $RetryDelaySeconds

    if ($job_id) {
        $logURL += "/job/$job_id"
    }

    Write-Log 'Log URL' $logURL

    return $logURL
}

Export-ModuleMember -Function Invoke-GithubRequest, Invoke-GithubGraphQL, Add-Comment, Get-AllChangedFilesInPR, New-Issue, Close-Issue, `
    Add-Label, Remove-Label, Get-RateLimit, Get-JobID, Get-LogURL, Get-RepositoryInfoAndPRs
