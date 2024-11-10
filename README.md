# Github Actions for Scoop buckets

Set of automated actions, which bucket maintainers can use to save time managing issues / pull requests.

## Available environment variables

1. `GITHUB_TOKEN`
    - **REQUIRED**
    - Use `${{ secrets.GITHUB_TOKEN }}`
1. `USER_EMAIL`
    - String
    - Optional
1. `SCOOP_REPO`
    - String
    - If specified, scoop config 'scoop_repo' will be configured and scoop updated
1. `SCOOP_BRANCH`
    - String
    - If specified, scoop config 'scoop_branch' will be configured and scoop updated
1. `SKIP_UPDATED`
    - String. Use `'1'` or `'0'`
    - If enabled, log of checkver utility will not print latest versions
1. `THROW_ERROR`
    - String. Use `'1'` or `'0'`
    - If enabled, error from checkver utility will be thrown as exception and cause the run to fail
1. `SPECIAL_SNOWFLAKES`
    - String
    - List of manifest names joined with `,` used as parameter for auto-pr utility.
1. `FORCE_PWSH`
    - String. Use `'1'` or `'0'`
    - If enabled, `pwsh` (PowerShell Core) will be used instead of `powershell` (Windows PowerShell).
    - Use `powershell` by default. More: [#38](https://github.com/ScoopInstaller/GithubActions/pull/38) [#39](https://github.com/ScoopInstaller/GithubActions/pull/39) [#46](https://github.com/ScoopInstaller/GithubActions/pull/46)

## Available actions

### Excavator

- [Protected default branches are not supported.](https://github.community/t5/GitHub-Actions/How-to-push-to-protected-branches-in-a-GitHub-Action/m-p/30710/highlight/true#M526)
- Periodically execute automatic updates for all manifests
- Refer to [workflow triggers](https://help.github.com/en/articles/events-that-trigger-workflows#scheduled-events) for configuration formats

### Issues

As soon as a new issue **is created** or the **label `verify` is added** to an issue, the action is executed.
Based on the issue title, a specific sub-action is executed.
It could be one of these:

- **Hash check fails**
    1. Checkhashes binary is executed for manifest in title
    1. Result is parsed
        1. Hash mismatch
            1. Pull requests with name `<manifest>@<version>: Fix hash` are listed
                1. There is PR already
                    1. The newest one is selected
                    1. Description of this PR is updated with closing directive for created issue
                    1. Comment to issue is posted with reference to PR
                    1. Label `duplicate` added
                1. If none
                    1. New branch `<manifest>-hash-fix-<random>` is created
                    1. Changes are commited
                    1. New PR is created from this branch
            1. Labels `hash-fix-needed`, `verified` are added
        1. No problem
            1. Comment on issue is posted about hashes being right and possible causes
            1. Label `hash-fix-needed` is removed
            1. Issue is closed
        1. Binary error
            1. Label `manifest-fix-needed` is added
- **Download failed**
    1. All urls defined in manifest are retrieved
    1. Downloading of all urls is executed
    1. Comment to issue is posted
        1. If there is problematic URL
            1. List of these URLs is attached in comment
            1. Labels `manifest-fix-needed`, `verified`, `help wanted` are added
        1. All URLs could be downloaded without problem
            1. Possible causes are attached in comment

### Pull Requests

As soon as a PR **is created** or the **comment `/verify` is posted** to it, validation tests are executed (see [wiki](https://github.com/ScoopInstaller/GithubActions/wiki/Pull-Request-Checks)) for detailed desciption):

#### Overview of validatiors

1. JSON standard format check
1. Required properties (`License`, `Description`) are in place
1. Hashes of files are correct
1. Checkver functionality
1. Autoupdate functionality
    1. Hash extraction finished

## Example workflows for all actions

- Names could be changed as desired
- `if` statements are not required
    - There are only time savers when finding appropriate action log
    - Save GitHub resources

```yml
#.github\workflows\schedule.yml
on:
  schedule:
  - cron: '*/30 * * * *'
name: Excavator
jobs:
  excavate:
    name: Excavator
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@main
    - name: Excavator
      uses: ScoopInstaller/GithubActions@main
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        SKIP_UPDATED: '1'
        THROW_ERROR: '0'
        FORCE_PWSH: '0'

#.github\workflows\issues.yml
on:
  issues:
    types: [ opened, labeled ]
name: Issue
jobs:
  issueHandler:
    name: Issue Handler
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@main
    - name: Issue Handler
      uses: ScoopInstaller/Scoop-GithubActions@main
      if: github.event.action == 'opened' || (github.event.action == 'labeled' && contains(github.event.issue.labels.*.name, 'verify'))
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

#.github\workflows\issue_commented.yml
on:
  issue_comment:
    types: [ created ]
name: Commented Pull Request
jobs:
  pullRequestHandler:
    name: Pull Request Validator
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@main
    - name: Pull Request Validator
      uses: ScoopInstaller/GithubActions@main
      if: startsWith(github.event.comment.body, '/verify')
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

#.github\workflows\pull_request.yml
on:
  pull_request_target:
    types: [ opened ]
name: Pull Requests
jobs:
  pullRequestHandler:
    name: Pull Request Validator
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@main
    - name: Pull Request Validator
      uses: ScoopInstaller/GithubActions@main
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
