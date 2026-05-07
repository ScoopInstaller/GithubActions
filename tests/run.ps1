#Requires -Version 5.1
#Requires -Modules Pester
#Requires -Modules PSScriptAnalyzer

$pesterConfig = New-PesterConfiguration -Hashtable @{
    Run    = @{
        Path     = "$PSScriptRoot"
        PassThru = $true
    }
    Should = @{
        # Continue running tests even if some assertions fail. This allows
        # Pester to collect and report all failures at the end of a test
        # instead of stopping at the first failing assertion.
        ErrorAction = 'Continue'
    }
    Output = @{
        StackTraceVerbosity = 'None'
        Verbosity           = 'Detailed'
    }
}
$result = Invoke-Pester -Configuration $pesterConfig
exit $result.FailedCount
