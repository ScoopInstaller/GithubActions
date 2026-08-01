Describe 'PR Title Validation' -Tag 'PRTitle' {
    BeforeAll {
        . "$PSScriptRoot\..\lint-pr-title\PRTitle.ps1"
    }

    Context 'Valid titles' {
        It 'Should accept new manifest: <manifest>: Add version <version>' {
            Test-PRTitle 'app-name: Add version 1.0' | Should -BeTrue
        }

        It 'Should accept manifest update: <manifest>@<version>: <description>' {
            Test-PRTitle 'app-name@1.0: fix download url' | Should -BeTrue
        }

        It 'Should accept wildcard: <manifest>(*): <description>' {
            Test-PRTitle 'app-name(*): update multiple manifests' | Should -BeTrue
        }

        It 'Should accept chore: (chore): <description>' {
            Test-PRTitle '(chore): update CI config' | Should -BeTrue
        }

        It 'Should accept single word manifest' {
            Test-PRTitle 'firefox: Add version 128.0' | Should -BeTrue
        }

        It 'Should accept manifest with numbers' {
            Test-PRTitle '7zip@24.08: update to latest' | Should -BeTrue
        }

        It 'Should accept manifest with hyphens in name' {
            Test-PRTitle 'gcc-arm-none-eabi@13.2: update' | Should -BeTrue
        }

        It 'Should accept manifest with dot in name' {
            Test-PRTitle 'app.name@1.0: update' | Should -BeTrue
        }

        It 'Should accept manifest with trailing hyphen' {
            Test-PRTitle 'notepad--@1.0: update' | Should -BeTrue
        }

        It 'Should accept suffix portion starting with hyphen' {
            Test-PRTitle 'app-name(-beta): update app-name and app-name-beta manifests' | Should -BeTrue
        }

        It 'Should accept suffix portion starting with dot' {
            Test-PRTitle 'app-name(.bar): update' | Should -BeTrue
        }

        It 'Should accept suffix portion with trailing hyphen' {
            Test-PRTitle 'app-name(-bar-): update' | Should -BeTrue
        }

        It 'Should accept version with pre-release tag' {
            Test-PRTitle 'nodejs@22.0.0-rc1: update to rc' | Should -BeTrue
        }
    }

    Context 'Invalid titles' {
        It 'Should reject uppercase manifest name' {
            Test-PRTitle 'App-Name: Add version 1.0' | Should -BeFalse
        }

        It 'Should reject suffix portion ending with dot' {
            Test-PRTitle 'app-name(-foo.): update' | Should -BeFalse
        }

        It 'Should reject partial wildcard in suffix portion' {
            Test-PRTitle 'app-name(beta*): update beta builds' | Should -BeFalse
        }

        It 'Should reject suffix portion of only hyphens or dots' {
            Test-PRTitle 'app-name(-): update' | Should -BeFalse
        }

        It 'Should reject uppercase in suffix portion' {
            Test-PRTitle 'app-name(Beta): update' | Should -BeFalse
        }

        It 'Should reject empty parenthesized portion' {
            Test-PRTitle 'app-name(): update' | Should -BeFalse
        }

        It 'Should reject version with whitespace' {
            Test-PRTitle 'app-name@1.0 beta: update' | Should -BeFalse
        }

        It 'Should reject leading hyphen' {
            Test-PRTitle '-app: Add version 1.0' | Should -BeFalse
        }

        It 'Should reject both wildcard and version' {
            Test-PRTitle 'app-name@1.0(*): invalid combo' | Should -BeFalse
        }

        It 'Should reject missing colon' {
            Test-PRTitle 'app-name Add version 1.0' | Should -BeFalse
        }

        It 'Should reject missing description' {
            Test-PRTitle 'app-name: ' | Should -BeFalse
        }

        It 'Should reject empty string' {
            Test-PRTitle '' | Should -BeFalse
        }

        It 'Should reject whitespace-only string' {
            Test-PRTitle '   ' | Should -BeFalse
        }

        It 'Should reject only colon' {
            Test-PRTitle ': no manifest' | Should -BeFalse
        }

        It 'Should reject space in manifest name' {
            Test-PRTitle 'app name: Add version 1.0' | Should -BeFalse
        }

        It 'Should reject underscore in manifest name' {
            Test-PRTitle 'app_name: Add version 1.0' | Should -BeFalse
        }

        It 'Should reject leading dot' {
            Test-PRTitle '.app: Add version 1.0' | Should -BeFalse
        }

        It 'Should reject trailing dot' {
            Test-PRTitle 'app.: Add version 1.0' | Should -BeFalse
        }
    }
}
