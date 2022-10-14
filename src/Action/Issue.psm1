Join-Path $PSScriptRoot '..\Helpers.psm1' | Import-Module

function Test-Hash {
    param (
        [Parameter(Mandatory = $true)]
        [String] $Manifest,
        [Int] $IssueID
    )

    $gci, $man = Get-Manifest $Manifest
    $manifestNameAsInBucket = $gci.BaseName

    $outputH = @(& (Join-Path $BINARIES_FOLDER 'checkhashes.ps1') -App $gci.Basename -Dir $MANIFESTS_LOCATION -Force *>&1)
    Write-Log 'Output' $outputH

    if (($outputH[-2] -like 'OK') -and ($outputH[-1] -like 'Writing*')) {
        Write-Log 'Cannot reproduce'

        Add-Comment -ID $IssueID -Message @(
            'Cannot reproduce'
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
        # There is some error
        Write-Log 'Automatic check of hashes encounter some problems.'

        Add-Label -Id $IssueID -Label 'manifest-fix-needed'
    } else {
        Write-Log 'Verified hash failed'

        $masterBranch = ((Invoke-GithubRequest "repos/$REPOSITORY").Content | ConvertFrom-Json).default_branch
        $message = @('You are right. Thank you for reporting.')
        # TODO: Post labels at the end of function
        Add-Label -ID $IssueID -Label 'verified', 'hash-fix-needed'
        $prs = (Invoke-GithubRequest "repos/$REPOSITORY/pulls?state=open&base=$masterBranch&sorting=updated").Content | ConvertFrom-Json
        $titleToBePosted = "$manifestNameAsInBucket@$($man.version): Fix hash"
        $prs = $prs | Where-Object { $_.title -eq $titleToBePosted }

        # There is alreay PR for
        if ($prs.Count -gt 0) {
            Write-Log 'PR - Update description'

            # Only take latest updated
            $pr = $prs | Select-Object -First 1
            $prID = $pr.number
            # TODO: Additional checks if this PR is really fixing same issue

            $message += ''
            $message += "There is already pull request which take care of this issue. (#$prID)"

            Write-Log 'PR ID' $prID
            # Update PR description
            Invoke-GithubRequest "repos/$REPOSITORY/pulls/$prID" -Method Patch -Body @{ 'body' = (@("- Closes #$IssueID", $pr.body) -join "`r`n") }
            Add-Label -ID $IssueID -Label 'duplicate'
        } else {
            # Check if default branch is protected
            if (((Invoke-GithubRequest "repos/$REPOSITORY/branches/$masterBranch").Content | ConvertFrom-Json).protected) {
                Write-Log 'PR - Create new branch and post PR'

                $branch = "$manifestNameAsInBucket-hash-fix-$(Get-Random -Maximum 258258258)"

                Write-Log 'Branch' $branch

                git checkout -B $branch
                # TODO: There is some problem

                Write-Log 'Git Status' @(git status --porcelain)

                git add $gci.FullName
                git commit -m $titleToBePosted
                git push origin $branch

                # Create new PR
                Invoke-GithubRequest -Query "repos/$REPOSITORY/pulls" -Method Post -Body @{
                    'title' = $titleToBePosted
                    'base'  = $masterBranch
                    'head'  = $branch
                    'body'  = "- Closes #$IssueID"
                }
            } else {
                Write-Log 'Push - Fix hash and push the commit'

                Write-Log 'Git Status' @(git status --porcelain)

                git add $gci.FullName
                git commit -m "$titleToBePosted (Closes #$IssueID)"
                git push
            }
        }
        Add-Comment -ID $IssueID -Message $message
    }
}

function Test-Downloading {
    param([String] $Manifest, [Int] $IssueID)

    $null, $object = Get-Manifest $Manifest

    $broken_urls = @()
    # TODO:? Aria2 support
    # Invoke-CachedAria2Download $Manifest 'DL' $object (default_architecture) "/" $object.cookies $true

    # exit 0
    foreach ($arch in @('64bit', '32bit', 'arm64')) {
        $urls = @(url $object $arch)

        foreach ($url in $urls) {
            # Trim rename (#48)
            $url = $url -replace '#/.*$', ''
            Write-Log 'url' $url

            try {
                Invoke-CachedDownload $Manifest 'DL' $url $null $object.cookies $true
            } catch {
                $broken_urls += $url
                continue
            }
        }
    }

    if ($broken_urls.Count -eq 0) {
        Write-Log 'All OK'

        $message = @(
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

        Add-Comment -ID $IssueID -Comment $message
        Close-Issue -ID $IssueID
    } else {
        Write-Log 'Broken URLS' $broken_urls

        $string = ($broken_urls | Select-Object -Unique | ForEach-Object { "- $_" }) -join "`r`n"
        Add-Label -ID $IssueID -Label 'manifest-fix-needed', 'verified', 'help wanted'
        Add-Comment -ID $IssueID -Comment 'Thank you for reporting. You are right.', '', 'Following URLs are not accessible:', '', $string
    }
}

function Initialize-Issue {
    Write-Log 'Issue initialized'

    if (-not (($EVENT.action -eq 'opened') -or ($EVENT.action -eq 'labeled'))) {
        Write-Log "Only actions 'opened' and 'labeled' are supported"
        return
    }

    $title = $EVENT.issue.title
    $id = $EVENT.issue.number
    $label = $EVENT.issue.labels.name

    # Only labeled action with verify label should continue
    if (($EVENT.action -eq 'labeled') -and ($label -notcontains 'verify')) {
        Write-Log 'Labeled action contains wrong label'
        return
    }

    $problematicName, $problematicVersion, $problem = Resolve-IssueTitle $title
    if (($null -eq $problematicName) -or
        ($null -eq $problematicVersion) -or
        ($null -eq $problem)
    ) {
        Write-Log 'Not compatible issue title'
        return
    }

    try {
        $null, $manifest_loaded = Get-Manifest $problematicName
    } catch {
        Add-Comment -ID $id -Message "The specified manifest ``$problematicName`` does not exist in this bucket. Make sure you opened the issue in the correct bucket."
        Add-Label -Id $id -Label 'invalid'
        Remove-Label -Id $id -Label 'verify'
        Close-Issue -ID $id
        return
    }

    if ($manifest_loaded.version -ne $problematicVersion) {
        Add-Comment -ID $id -Message @(
            # TODO: Try to find specific version of arhived manifest
            "You reported version ``$problematicVersion``, but the latest available version is ``$($manifest_loaded.version)``."
            ''
            "Run ``scoop update; scoop update $problematicName --force``"
        )
        Close-Issue -ID $id
        Remove-Label -Id $id -Label 'verify'
        return
    }

    switch -Wildcard ($problem) {
        '*hash check*' {
            Write-Log 'Hash check failed'
            Test-Hash $problematicName $id
        }
        '*extract_dir*' {
            Write-Log 'Extract dir error'
            # TODO:
            # Test-ExtractDir $problematicName $id
        }
        '*download*failed*' {
            Write-Log 'Download failed'
            Test-Downloading $problematicName $id
        }
        default { Write-Log 'Not supported issue action' }
    }

    Remove-Label -ID $id -Label 'verify'
    Write-Log 'Issue finished'
}

Export-ModuleMember -Function Initialize-Issue
