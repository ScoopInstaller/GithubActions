Join-Path $PSScriptRoot '..\..\Helpers.psm1' | Import-Module

function Test-ExtractDir {
    param([String] $Manifest, [Int] $IssueID)

    # Load manifest
    $manifest_path = Get-ChildItem $MANIFESTS_LOCATION "$Manifest.*" | Select-Object -First 1 -ExpandProperty Fullname
    $manifest_o = Get-Content $manifest_path -Raw | ConvertFrom-Json

    $message = @()
    $failed = $false
    $version = 'EXTRACT_DIR'

    foreach ($arch in @('64bit', '32bit', 'arm64')) {
        $urls = @(url $manifest_o $arch)
        $extract_dirs = @(extract_dir $manifest_o $arch)

        Write-Log $urls
        Write-Log $extract_dirs

        for ($i = 0; $i -lt $urls.Count; ++$i) {
            $url = $urls[$i]
            $dir = $extract_dirs[$i]
            Invoke-CachedDownload $Manifest $version $url $null $manifest_o.cookie $true

            $cached = cache_path $Manifest $version $url | Resolve-Path | Select-Object -ExpandProperty Path
            Write-Log "FILEPATH $url, ${arch}: $cached"

            $full_output = @(7z l $cached | awk '{ print $3, $6 }' | grep '^D')
            $output = @(7z l $cached -ir!"$dir" | awk '{ print $3, $6 }' | grep '^D')

            $infoLine = $output | Select-Object -Last 1
            $status = $infoLine -match '(?<files>\d+)\s+files(,\s+(?<folders>\d+)\s+folders)?'
            if ($status) {
                $files = $Matches.files
                $folders = $Matches.folders
            }

            # There are no files and folders like
            if ($files -eq 0 -and (!$folders -or $folders -eq 0)) {
                Write-Log "No $dir in $url"

                $failed = $true
                $message += New-DetailsCommentString -Summary "Content of $arch $url" -Content $full_output
                Write-Log "$dir, $arch, $url FAILED"
            } else {
                Write-Log "Cannot reproduce $arch $url"

                Write-Log "$arch ${url}:"
                Write-Log $full_output
                Write-Log "$dir, $arch, $url OK"
            }
        }
    }

    if ($failed) {
        Write-Log 'Failed' $failed
        $message = 'You are right. Can reproduce', '', $message
        Add-Label -ID $IssueID -Label 'verified', 'manifest-fix-needed', 'help wanted'
    } else {
        Write-Log 'Everything all right' $failed
        $message = @(
            'Cannot reproduce. Are you sure your scoop is updated?'
            "Try to run ``scoop update; scoop uninstall $Manifest; scoop install $Manifest``"
            ''
            'See action log for additional info'
        )
    }

    Add-Comment -ID $IssueID -Message $message -AppendLogLink
}

function Show-ExtractionHelpTips {
    param (
        [Parameter(Mandatory = $true)]
        [String] $App,
        [Int] $IssueID,
        [string] $IssueBody
    )

    # Tips from Scoop common known issues:
    # https://github.com/ScoopInstaller/Scoop/issues/6378
    $tips = [Ordered] @{
        '7zip'    = @(
            '- 7zip package decompression/extraction error',
            'Make sure you have the latest version of `7zip` installed:',
            '  ```',
            '  scoop update 7zip',
            '  ```',
            '  If you have enabled `use_external_7zip`, update it using the appropriate method for your setup.'
        )
        'msi'     = @(
            '- MSI package decompression/extraction error',
            '  - If you are using default MSI extractor (msiexec):',
            '  This is usually caused by a msiexec process exception, try one of them:',
            '    - Switch to alternative MSI extractor then retry: `scoop config use_lessmsi true` (Default: false).',
            '    - Resolve the msiexec exception/occupation then retry, if you know about it.',
            '    - Restart the PC then retry.',
            '',
            '    Learn more: https://learn.microsoft.com/en-us/windows/win32/msi/error-codes',
            '  - If you are using alternative MSI extractor (lessmsi):',
            '    - Switch to default MSI extractor then retry: `scoop config use_lessmsi false` (Default: false).'
        )
        'innounp' = @(
            '- Inno Setup package decompression/extraction error',
            'Make sure you have the latest version of `innounp` or `innounp-unicode` installed:',
            '  ```',
            '  scoop update innounp',
            '  ```',
            '  ```',
            '  scoop update innounp-unicode',
            '  ```',
            '> [!IMPORTANT]',
            '> **Sometimes, the latest version of innounp may not support unpacking the latest Inno Setup packages.**',
            '> **You might need to wait for an upstream update of innounp.**',
            '> See: https://github.com/jrathlev/InnoUnpacker-Windows-GUI?tab=readme-ov-file#inspect-and-unpack-innosetup-archives'
        )
        'dark'    = @(
            '- WiX package decompression/extraction error',
            'Make sure you have the latest version of `dark` installed:',
            '  ```',
            '  scoop update dark',
            '  ```'
        )
    }

    $tipHead = @(
        'Decompression/extraction errors can be caused by various reasons. Here are some common solutions you can try:'
    )

    $tipTail = @(
        'If none of the above solutions work, it may be caused by other reasons like:',
        '- Extraction blocked by antivirus.',
        '- Extraction failed due to insufficient disk space.',
        '- Extraction method outdated due to changes in upstream package type or structure. May need a manual fix for manifest.',
        '- ...',
        '',
        'If the problem persists, please keep this issue open and paste the log content from the failed installation, if available.',
        'This will help us diagnose and resolve the issue more effectively.',
        '> [!WARNING]',
        '> If you are using an unofficial Scoop-Core with an official bucket,',
        '> the decompress error may be caused by significant differences between the official and unofficial cores.',
        '> In this case, please try switching to the official [Scoop-Core](https://github.com/ScoopInstaller/Scoop) instead.'
    )

    $tipContent = @()

    switch -Regex ($IssueBody) {
        '7zip' { $tipContent += $tips['7zip']; $tipContent += '' }
        'msi' { $tipContent += $tips['msi']; $tipContent += '' }
        'innounp' { $tipContent += $tips['innounp']; $tipContent += '' }
        'dark' { $tipContent += $tips['dark']; $tipContent += '' }
        default {
            $tips.Values | ForEach-Object {
                $tipContent += $_;
                $tipContent += ''
            }
        }
    }

    $message = $tipHead + $tipContent + $tipTail

    Add-Comment -ID $IssueID -Message $message
}

Export-ModuleMember -Function Test-ExtractDir, Show-ExtractionHelpTips
