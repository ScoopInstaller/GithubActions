Join-Path $PSScriptRoot '..\Helpers.psm1' | Import-Module

function Start-PR {
    <#
    .SYNOPSIS
        PR state handler.
    .OUTPUTS
        $null - Not supported state, which should be exited on.
        $true | $false
    #>
    $commented = $false

    switch ($EVENT.action) {
        'opened' {
            Write-Log 'Opened PR'
        }
        'created' {
            Write-Log 'Commented PR'

            if ($EVENT.comment.body -like '/verify*') {
                Write-Log 'Verify comment'

                if ($EVENT.issue.pull_request) {
                    Write-Log 'Pull request comment'

                    $commented = $true
                    # There is need to get actual pull request event
                    $content = Invoke-GithubRequest "repos/$REPOSITORY/pulls/$($EVENT.issue.number)" | Select-Object -ExpandProperty Content
                    $script:EVENT_new = ConvertFrom-Json $content
                } else {
                    Write-Log 'Issue comment'
                    $commented = $null # No need to do anything on issue comment
                }
            } else {
                Write-Log 'Not supported comment body'
                $commented = $null
            }
        }
        default {
            Write-Log 'Only action ''opened'' is supported'
            $commented = $null
        }
    }

    return $commented
}

function Set-RepositoryContext {
    <#
    .SYNOPSIS
        Repository context of commented PR is not set to correct $head.ref.
    #>
    param ([Parameter(Mandatory)] $Ref)

    if ((git branch --show-current) -ne $Ref) {
        Write-Log "Switching branch to $Ref"

        git fetch --all
        git checkout $Ref
        git pull
    }
}

function New-FinalMessage {
    <#
    .SYNOPSIS
        Create and post final comment with information for collaborators.
    .PARAMETER Check
        Array of manifests checks.
    .PARAMETER Invalid
        Array of invalid manifests.
    #>
    param(
        [Object[]] $Check,
        [String[]] $Invalid
    )

    $prID = $EVENT.number
    $message = New-Array

    foreach ($ch in $Check) {
        Add-IntoArray $message "### $($ch.Name)"
        Add-IntoArray $message ''
        New-CheckList $ch.Statuses | ForEach-Object { Add-IntoArray $message $_ }
        Add-IntoArray $message ''
    }

    if ($Invalid.Count -gt 0) {
        Write-Log 'PR contains invalid manifests'

        $env:NON_ZERO_EXIT = $true
        Add-IntoArray $message '### Invalid manifests'
        Add-IntoArray $message ''
        $Invalid | ForEach-Object { Add-IntoArray $message "- $_" }
    }

    $labelsToAdd = @()
    $labelsToRemove = @()
    # Add some more human friendly message
    if ($env:NON_ZERO_EXIT) {
        $message.Insert(0, '[Your changes do not pass checks.](https://github.com/ScoopInstaller/GithubActions/wiki/Pull-Request-Checks)')
        $labelsToAdd += 'manifest-fix-needed'
        $labelsToRemove += 'review-needed'
    } else {
        $message.InsertRange(0, @('All changes look good.', '', 'Wait for review from human collaborators.'))
        $labelsToAdd += 'review-needed'
        $labelsToRemove += 'manifest-fix-needed'
    }

    # TODO: Comment URL to action log
    # Add-IntoArray $message "[_See log of all checks_](https://github.com/$REPOSITORY/runs/$RUN_ID)"

    Remove-Label -ID $prID -Label $labelsToRemove
    Add-Label -ID $prID -Label $labelsToAdd
    Add-Comment -ID $prID -Message $message
}

function Test-PRFile {
    <#
    .SYNOPSIS
        Validate all changed files.
    .PARAMETER File
        Changed files in pull request.
    .OUTPUTS
        Tupple of check object and array of invalid manifests.
    #>
    param([Object[]] $File)

    $check = @()
    $invalid = @()
    foreach ($f in $File) {
        Write-Log "Starting $($f.filename) checks"

        # Reset variables from previous iteration
        $manifest = $null
        $object = $null
        $statuses = [Ordered] @{ }

        # Convert path into gci item to hold all needed information
        $manifest = Get-ChildItem $BUCKET_ROOT $f.filename
        Write-Log 'Manifest' $manifest

        # For Some reason -ErrorAction is not honored for convertfrom-json
        $old_e = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $object = Get-Content $manifest.Fullname -Raw | ConvertFrom-Json
        $ErrorActionPreference = $old_e

        if ($null -eq $object) {
            Write-Log 'Conversion failed'

            # Handling of configuration files (vscode, ...) will not be problem as soon as nested bucket folder is restricted
            Write-Log 'Extension' $manifest.Extension

            if ($manifest.Extension -eq '.json') {
                Write-Log 'Invalid JSON'
                $invalid += $manifest.Basename
            } else {
                Write-Log 'Not manifest at all'
            }
            Write-Log "Skipped $($f.filename)"
            continue
        }

        #region 1. Property checks
        $statuses.Add('Description', ([bool] $object.description))
        $statuses.Add('License', ([bool] $object.license))
        # TODO: More advanced license checks
        #endregion 1. Property checks

        #region 2. Hashes
        if ($object.version -ne 'nightly') {
            Write-Log 'Hashes'
            $outputH = @(& (Join-Path $BINARIES_FOLDER 'checkhashes.ps1') -App $manifest.Basename -Dir $MANIFESTS_LOCATION *>&1)
            Write-Log 'Output' $outputH

            # Everything should be all right when latest string in array will be OK
            $statuses.Add('Hashes', ($outputH[-1] -like 'OK'))

            Write-Log 'Hashes done'
        }
        #endregion 2. Hashes

        #region 3. Checkver and 4. Autoupdate
        if ($object.checkver) {
            Write-Log 'Checkver'
            $outputV = @(& (Join-Path $BINARIES_FOLDER 'checkver.ps1') -App $manifest.Basename -Dir $MANIFESTS_LOCATION -Force *>&1)
            Write-log 'Output' $outputV

            $joinedOutputV = $outputV -join ' '
            # Try to match "<manifest-name>: <version>" from outputV
            $checkverRegex = "$([regex]::escape($manifest.Basename)):\s*$([regex]::escape($($object.version)))"
            $checkver = $joinedOutputV -match $checkverRegex
            $statuses.Add('Checkver', $checkver)
            Write-Log 'Checkver done'

            #region Autoupdate
            if ($object.autoupdate) {
                Write-Log 'Autoupdate'
                $autoupdate = $false
                switch -Wildcard ($outputV[-1]) {
                    'ERROR*' {
                        Write-Log 'Error in checkver'
                    }
                    "couldn't match*" {
                        Write-Log 'Version match fail'
                    }
                    'Writing updated*' {
                        Write-Log 'Autoupdate finished successfully'
                        $autoupdate = $true
                    }
                    default { $autoupdate = $checkver }
                }
                $statuses.Add('Autoupdate', $autoupdate)

                # There is some hash property defined in autoupdate
                if ($object.autoupdate.hash -or ($object.autoupdate.architecture.PSObject.Properties.Value | Where-Object -Property hash)) {
                    # Or use `($object | ConvertTo-Json -Depth 8) -match '(?s)"autoupdate".*?"hash"'`
                    $result = $autoupdate
                    if ($result) {
                        # If any result contains any item with 'Could not find hash*' there is hash extraction error.
                        $result = (($outputV -like 'Could not find hash*').Count -eq 0)
                    }
                    $statuses.Add('Autoupdate Hash Extraction', $result)
                }
                Write-Log 'Autoupdate done'
            }
            #endregion Autoupdate
        }
        #endregion 3. Checkver and 4. Autoupdate

        #region 5. Manifest format
        # Write-Log 'Format'
        # TODO: implement format check using array compare if possible (or just strings with raws)
        # TODO: I am not sure if this will handle tabs and everything what could go wrong.
        #$raw = Get-Content $manifest.Fullname -Raw
        #$new_raw = $object | ConvertToPrettyJson
        #$statuses.Add('Format', ($raw -eq $new_raw))
        # Write-Log 'Format done'
        #endregion 4. Manifest format

        #region 6. Installation
        # Write-Log 'Installation'
        # # Try catch as currently some components are throwing exceptions
        # try {
        #     $outputI = @(scoop install $manifest.FullName *>&1)
        # } catch {
        #     Write-Log 'Installation failed' # Mainly due to some manifest script problem
        #     $installation = $false
        # }

        # if ($outputI) {
        # }

        # $statuses.Add('Installation', $installation)
        # Write-Log 'Installation done'
        #endregion 6. Installation

        #region 7. Uninstallation
        # Write-Log 'Uninstallation'
        # Write-Log 'Uninstallation done'
        #endregion 7. Uninstallation

        $check += [Ordered] @{ 'Name' = $manifest.Basename; 'Statuses' = $statuses }

        Write-Log "Finished $($f.filename) checks"
    }

    return $check, $invalid
}

function Initialize-PR {
    <#
    .SYNOPSIS
        Handle pull requests action.
    .DESCRIPTION
        1. Clone repository / Switch to correct branch
        2. Validate all changed manifests
        3. Post comment with check results
    #>
    Write-Log 'PR initialized'

    # required to access releases in private GitHub repos
    $env:SCOOP_GH_TOKEN = $env:GITHUB_TOKEN

    #region Stage 1 - Repository initialization
    $commented = Start-PR
    if ($null -eq $commented) { return } # Exit on not supported state
    Write-Log 'Commented?' $commented

    $EVENT | ConvertTo-Json -Depth 8 -Compress | Write-Log 'Pure PR Event'
    if ($EVENT_new) {
        Write-Log 'There is new event available'
        $EVENT = $EVENT_new
        $EVENT | ConvertTo-Json -Depth 8 -Compress | Write-Log 'New Event'
    }

    # TODO: Ternary
    $head = if ($commented) { $EVENT.head } else { $EVENT.pull_request.head }

    if ($head.repo.fork) {
        Write-Log 'Forked repository'

        # There is no need to run whole action under forked repository due to permission problem
        # if ($commented -eq $false) {
        #     Write-Log 'Cannot comment with read only token'
        #     # TODO: Execute it and adopt pester like checks
        #     return
        # }

        $REPOSITORY_forked = "$($head.repo.full_name):$($head.ref)"
        Write-Log 'Repo' $REPOSITORY_forked

        $cloneLocation = "${env:TMP}\forked_repository"
        git clone --branch $head.ref $head.repo.clone_url $cloneLocation
        $script:BUCKET_ROOT = $cloneLocation
        $buck = Join-Path $BUCKET_ROOT 'bucket'
        # TODO: Ternary
        $script:MANIFESTS_LOCATION = if (Test-Path $buck) { $buck } else { $BUCKET_ROOT }

        Write-Log "Switching to $REPOSITORY_forked"
        Push-Location $cloneLocation
    }

    # Repository context of commented PR is not set to $head.ref
    Set-RepositoryContext $head.ref
    #endregion Stage 1 - Repository initialization

    # In case of forked repository it needs to be '/github/forked_workspace'
    Get-Location | Write-Log 'Context of action'
    (Get-ChildItem $BUCKET_ROOT | Select-Object -ExpandProperty Basename) -join ', ' | Write-log 'Root Files'
    (Get-ChildItem $MANIFESTS_LOCATION -Filter '*.json' -Recurse | Select-Object -ExpandProperty Basename) -join ', ' | Write-log 'Manifests'

    # Do not run checks on removed files
    $files = Get-AllChangedFilesInPR $EVENT.number -Filter
    Write-Log 'PR Changed Files' $files
    $files = $files | Where-Object -Property 'filename' -Like -Value 'bucket/*'
    Write-Log 'Only Changed Manifests' $files

    # Stage 2 - Manifests validation
    $check, $invalid = Test-PRFile $files

    #region Stage 3 - Final Message
    Write-Log 'Checked manifests' $check.name
    Write-Log 'Invalids' $invalid

    if (($check.Count -eq 0) -and ($invalid.Count -eq 0)) {
        Write-Log 'No compatible files in PR'
        return
    }

    # TODO: Pester like check
    New-FinalMessage $check $invalid
    #endregion Stage 3 - Final Message

    Write-Log 'PR finished'
}

Export-ModuleMember -Function Initialize-PR
