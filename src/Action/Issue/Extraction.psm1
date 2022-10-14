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

    Add-Comment -ID $IssueID -Message $message
}

Export-ModuleMember -Function Test-ExtractDir
