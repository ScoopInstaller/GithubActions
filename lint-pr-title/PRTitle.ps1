function Test-PRTitle {
    <#
    .SYNOPSIS
        Validate that a PR title follows the Scoop naming convention.
    .PARAMETER Title
        Pull request title to validate.
    .EXAMPLE
        Test-PRTitle 'app-name@1.0: fix download url'
    .EXAMPLE
        Test-PRTitle '(chore): update CI config'
    #>
    param([String] $Title)

    if ([string]::IsNullOrEmpty($Title)) { return $false }

    $re = '^(\(chore\)|[a-z0-9]([a-z0-9.-]*[a-z0-9-])?(\(\*\)|\((?=[a-z0-9.-]*[a-z0-9])[a-z0-9.-]*[a-z0-9-]\)|@[^\s:(]+)?): .+'
    return $Title -cmatch $re
}
