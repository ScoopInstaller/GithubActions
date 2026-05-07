Join-Path $PSScriptRoot '..\Helpers.psm1' | Import-Module
Join-Path $PSScriptRoot 'Issue' | Get-ChildItem -Filter '*.psm1' | Select-Object -ExpandProperty Fullname | Import-Module

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $GitArgs
    )

    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Test-Hash {
    param (
        [Parameter(Mandatory = $true)]
        [String] $Manifest,
        [Int] $IssueID
    )

    $gci, $man = Get-Manifest $Manifest
    $manifestNameAsInBucket = $gci.BaseName

    try {
        $outputH = @(& (Join-Path $BINARIES_FOLDER 'checkhashes.ps1') -App $manifestNameAsInBucket -Dir $MANIFESTS_LOCATION -Force *>&1)
    } catch {
        $outputH = @("Exception occurred: $($_.Exception.Message)", "$($_.ScriptStackTrace)")
    }

    Write-LogInfo 'Output' $outputH

    if (($outputH[-2] -like 'OK') -and ($outputH[-1] -like 'Writing*')) {
        Write-LogInfo 'Cannot reproduce.'

        Add-Comment -ID $IssueID -AppendLogLink -Message @(
            'Cannot reproduce.'
            ''
            'Are you sure your scoop is up to date? Clean cache and reinstall'
            "Please run ``scoop update; scoop cache rm $manifestNameAsInBucket;`` and update/reinstall application"
            ''
            'Hash mismatch could be caused by these factors:'
            ''
            '- Network error'
            '- Antivirus configuration'
            '- Blocked site (Great Firewall of China, Corporate restrictions, ...)'
        )
        Remove-Label -ID $IssueID -Label 'hash-fix-needed'
        Close-Issue -ID $IssueID
    } elseif ($outputH[-1] -notlike 'Writing*') {
        Write-LogInfo 'Automatic hash verification encountered some problems.'

        Add-Label -ID $IssueID -Label 'help wanted'

        $message = @()

        if ($outputH[0] -like 'Exception occurred: *') {
            $message += @("> $($outputH[0])", '')
        }

        $message += @(
            'Automatic hash verification encountered some problems.'
            ''
            'Potential causes:'
            '- Network issue: Temporary connectivity loss, DNS resolution failures, or general network instability.'
            '- GitHub API: Rate limiting or permission denied.'
            "- Website Blocks: Anti-bot mechanisms or IP blocks targeting GitHub's hosted runner networks."
            '- Internal exception: An error originating from verification script itself.'
            ''
            'Please try again later. If it persists, please reach out to the maintainers for help.'
        )

        Add-Comment -ID $IssueID -Message $message -AppendLogLink
    } else {
        Write-LogInfo 'Hash mismatch confirmed.'

        $masterBranch = ((Invoke-GithubRequest "repos/$REPOSITORY").Content | ConvertFrom-Json).default_branch
        $message = @('You are right. Thank you for reporting.')
        # TODO: Post labels at the end of function
        Add-Label -ID $IssueID -Label 'verified', 'hash-fix-needed'
        $prs = (Invoke-GithubRequest "repos/$REPOSITORY/pulls?state=open&base=$masterBranch&sorting=updated").Content | ConvertFrom-Json
        $titleToBePosted = "$manifestNameAsInBucket@$($man.version): Fix hash"
        $prs = $prs | Where-Object { $_.title -eq $titleToBePosted }

        # There is alreay PR for
        if ($prs.Count -gt 0) {
            Write-LogInfo 'PR - Update description'

            # Only take latest updated
            $pr = $prs | Select-Object -First 1
            $prID = $pr.number
            # TODO: Additional checks if this PR is really fixing same issue

            $message += ''
            $message += "There is already a pull request which takes care of this issue. (#$prID)"

            Write-LogInfo 'PR ID' $prID
            # Update PR description
            Invoke-GithubRequest "repos/$REPOSITORY/pulls/$prID" -Method Patch -Body @{ 'body' = (@("- Closes #$IssueID", $pr.body) -join "`r`n") }
            Add-Label -ID $IssueID -Label 'duplicate'
        } else {
            Write-LogInfo 'Git Status:'
            Invoke-Git -GitArgs @('status', '--porcelain')

            Invoke-Git -GitArgs @('add', $gci.FullName)
            Invoke-Git -GitArgs @('commit', '-m', "$titleToBePosted (Closes #$IssueID)")

            # Try direct push
            try {
                Write-LogInfo 'Commiting fix directly'
                Invoke-Git -GitArgs @('push')
            } catch {
                Write-LogInfo 'Direct push failed. Probably protected branch. Will try to create PR instead.'

                $branch = "$manifestNameAsInBucket-hash-fix-$(Get-Random -Maximum 258258258)"
                Write-LogInfo 'Branch' $branch

                Invoke-Git -GitArgs @('checkout', '-B', $branch)
                # Amend commit with new message
                Invoke-Git -GitArgs @('commit', '--amend', '-m', "$titleToBePosted")

                # Try create branch and PR
                try {
                    Write-LogInfo 'Creating branch'
                    Invoke-Git -GitArgs @('push', 'origin', $branch)
                } catch {
                    Write-LogInfo 'Create branch failed. Please check workflow permissions.'
                    Add-Comment -ID $IssueID -AppendLogLink -Message @(
                        'Hash mismatch confirmed, but the bot could not publish the fix currently.'
                    )
                    return
                }

                try {
                    Write-LogInfo 'Creating PR'

                    # Create new PR
                    Invoke-GithubRequest -Query "repos/$REPOSITORY/pulls" -Method Post -Body @{
                        'title' = $titleToBePosted
                        'base'  = $masterBranch
                        'head'  = $branch
                        'body'  = "- Closes #$IssueID"
                    }
                } catch {
                    Write-LogInfo 'Create PR failed. Please check workflow permissions.'
                    # Try to delete branch if PR creation failed
                    try {
                        Invoke-Git -GitArgs @('push', 'origin', '--delete', $branch)
                    } catch {
                        Write-LogInfo 'Failed to delete branch. Please check workflow permissions.'
                    }
                    Add-Comment -ID $IssueID -AppendLogLink -Message @(
                        'Hash mismatch confirmed, but the bot could not publish the fix currently.'
                    )
                    return
                }
            }
        }
        Add-Comment -ID $IssueID -Message $message -AppendLogLink
    }
}

function Test-Downloading {
    param (
        [Parameter(Mandatory = $true)]
        [String] $Manifest,
        [Int] $IssueID
    )

    $gci, $man = Get-Manifest $Manifest

    $outputH = @(& (Join-Path $BINARIES_FOLDER 'checkurls.ps1') -App $gci.BaseName -Dir $MANIFESTS_LOCATION *>&1)
    $broken_urls = $outputH -match '>' -replace '.*?>', '-'

    if (!$broken_urls) {
        Write-LogInfo 'Cannot reproduce'

        Add-Comment -ID $IssueID -AppendLogLink -Message @(
            'Cannot reproduce.'
            ''
            'All files could be downloaded without any issue.'
            'Problems with download could be caused by:'
            ''
            '- Network error'
            '- Blocked site (Great Firewall of China, Corporate restrictions, ...)'
            '- Antivirus settings blocking URL/downloaded file'
            '- Proxy configuration'
            '- Aria2 being unreliable (if you''re facing problems with aria2, disable it by running `scoop config aria2-enabled false` and try again)'
        )

        Remove-Label -ID $IssueID -Label 'manifest-fix-needed'
        Close-Issue -ID $IssueID
    } else {
        Write-LogInfo 'Broken URLs' $broken_urls

        Add-Comment -ID $IssueID -AppendLogLink -Message (@(
                'You are right. Thank you for reporting.',
                '',
                'Following URLs are not accessible:'
            ) + $broken_urls)
        Add-Label -ID $IssueID -Label 'manifest-fix-needed', 'verified', 'help wanted'
    }
}

function Initialize-Issue {
    Write-LogInfo 'Issue initialized'

    if (-not (($GITHUB_EVENT.action -eq 'opened') -or ($GITHUB_EVENT.action -eq 'labeled'))) {
        Write-LogInfo "Only actions 'opened' and 'labeled' are supported"
        return
    }

    $title = $GITHUB_EVENT.issue.title
    $id = $GITHUB_EVENT.issue.number
    $label = $GITHUB_EVENT.issue.labels.name
    $body = $GITHUB_EVENT.issue.body

    # Only labeled action with verify label should continue
    if (($GITHUB_EVENT.action -eq 'labeled') -and ($label -notcontains 'verify')) {
        Write-LogInfo 'Labeled action contains wrong label'
        return
    }

    $problematicName, $problematicVersion, $problem = Resolve-IssueTitle $title
    if (($null -eq $problematicName) -or
        ($null -eq $problematicVersion) -or
        ($null -eq $problem)
    ) {
        Write-LogInfo 'Not compatible issue title'
        return
    }

    try {
        $null, $manifest_loaded = Get-Manifest $problematicName
    } catch {
        Add-Comment -ID $id -AppendLogLink -Message "The specified manifest ``$problematicName`` does not exist in this bucket. Make sure you opened the issue in the correct bucket."
        Add-Label -Id $id -Label 'invalid'
        Remove-Label -Id $id -Label 'verify'
        Close-Issue -ID $id
        return
    }

    if ($manifest_loaded.version -ne $problematicVersion) {
        Add-Comment -ID $id -AppendLogLink -Message @(
            # TODO: Try to find specific version of arhived manifest
            "You reported version ``$problematicVersion``, but the latest available version is ``$($manifest_loaded.version)``."
            ''
            "Run ``scoop update; scoop update $problematicName --force``"
        )
        Close-Issue -ID $id
        Remove-Label -Id $id -Label 'verify'
        return
    }

    switch -Regex ($problem) {
        'hash check' {
            Write-LogInfo 'Detected issue type' 'Hash check failed.'
            Test-Hash $problematicName $id
        }
        'download.*failed' {
            Write-LogInfo 'Detected issue type' 'Download failed.'
            Test-Downloading $problematicName $id
        }
        '(decompress|extract).*error' {
            Write-LogInfo 'Detected issue type' 'Decompression/Extraction error.'
            Show-ExtractionHelpDoc -IssueID $id -IssueBody $body
        }
        default { Write-LogInfo 'Unsupported issue type' $problem }
    }

    Remove-Label -ID $id -Label 'verify'
    Write-LogInfo 'Issue finished'
}

Export-ModuleMember -Function Initialize-Issue
