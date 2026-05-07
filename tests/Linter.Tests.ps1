Describe 'PowerShell Code Style' -Tag 'PSScriptAnalyzer' {
    BeforeAll {
        $formatSettings = "$PSScriptRoot\..\.psformatrules.psd1"
        $lintSettings = "$PSScriptRoot\..\.pslintrules.psd1"
    }

    It 'PSScriptAnalyzer rules files should exist' {
        $formatSettings | Should -Exist
        $lintSettings | Should -Exist
    }

    Context 'PowerShell code formatting' {
        BeforeAll {
            $records = Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\" `
                -Recurse -Settings $formatSettings
        }
        It 'Code should be formatted' {
            $records.Count | Should -Be 0
        }
        AfterAll {
            if ($records) {
                foreach ($r in $records) {
                    $type = 'Unknown'
                    switch -wildCard ($r.ScriptName) {
                        '*.psm1' { $type = 'Module' }
                        '*.ps1' { $type = 'Script' }
                        '*.psd1' { $type = 'Manifest' }
                        default { $type = 'Unknown' }
                    }
                    $scriptPath = Resolve-Path -Relative $r.ScriptPath
                    $color = switch ($r.Severity) {
                        'Error' { 'Red' }
                        'Warning' { 'Yellow' }
                        'Information' { 'White' }
                        default { 'White' }
                    }
                    Write-Host -f $color "     [!] $($r.Severity): $($r.Message)"
                    Write-Host -f $color "         $($r.RuleName) in $type`: $($scriptPath):$($r.Line)"
                }
            }
        }
    }

    Context 'PowerShell code linting' {
        BeforeAll {
            $records = Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\" `
                -Recurse -Settings $lintSettings
        }
        It 'Code should be linted' {
            $records.Count | Should -Be 0
        }
        AfterAll {
            if ($records) {
                foreach ($r in $records) {
                    $type = 'Unknown'
                    switch -wildCard ($r.ScriptName) {
                        '*.psm1' { $type = 'Module' }
                        '*.ps1' { $type = 'Script' }
                        '*.psd1' { $type = 'Manifest' }
                        default { $type = 'Unknown' }
                    }
                    $scriptPath = Resolve-Path -Relative $r.ScriptPath
                    $color = switch ($r.Severity) {
                        'Error' { 'Red' }
                        'Warning' { 'Yellow' }
                        'Information' { 'White' }
                        default { 'White' }
                    }
                    Write-Host -f $color "     [!] $($r.Severity): $($r.Message)"
                    Write-Host -f $color "         $($r.RuleName) in $type`: $($scriptPath):$($r.Line)"
                }
            }
        }
    }
}
