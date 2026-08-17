# ScoopInstaller/GithubActions

> Set of GitHub Actions for Scoop ecosystem.

[![CI][ci-badge]][ci-url] [![release][release-badge]][releases] [![license][license-badge]](LICENSE) [![discord][discord-badge]][discord-url]

In this repository, you can find a set of GitHub Actions that are used in Scoop
ecosystem, especially for Scoop bucket maintainers to maintain buckets in a less
manual way.

## Getting started

We recommend using the [`ScoopInstaller/BucketTemplate`][ScoopInstaller/BucketTemplate]
repository to create your own bucket repository if you are a new bucket maintainer.
It is a template repository that contains all the necessary files and configurations,
including GitHub Actions from this repository, to help you get started quickly.

### Actions

#### Excavator

The **Excavator** action is responsible for automating the update process of
Scoop manifests. It checks for new versions of software and updates the
corresponding manifests periodically.

```yaml
# .github/workflows/excavator.yml
name: Excavator
on:
  schedule:
  - cron: '20 */4 * * *' # Runs every 4 hours
permissions:
  contents: write
jobs:
  excavate:
    name: Excavate
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - name: Excavate
        uses: ScoopInstaller/GithubActions@main
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SKIP_UPDATED: 1
```

#### Issues

The `Issues` action triages issues in the bucket repository. It is executed when
a new issue is created or the label `verify` is added to an existing issue.

```yaml
# .github/workflows/issues.yml
name: Issue
on:
  issues:
    types: [opened, labeled]
permissions:
  # Auto hash fixing commits
  contents: write
  issues: write
jobs:
  issueHandler:
    name: IssueHandler
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - name: IssueHandler
        uses: ScoopInstaller/GithubActions@main
        if: github.event.action == 'opened' || (github.event.action == 'labeled' && contains(github.event.issue.labels.*.name, 'verify'))
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Based on the issue title, a specific sub-action is executed. It could be one of:

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
- **Decompression/Extraction error**
    1. Comment to issue is posted
        1. If one or more specific extraction tool names (7zip|msi|innounp|dark) are mentioned in the issue description
            1. Only related extraction help tips will be added in comment
        1. None of the specific extraction tool names are mentioned in the issue description
            1. All extraction help tips will be added in comment

#### Pull Requests

The `Pull Requests` action validates pull requests in the bucket repository. It
is executed when a new pull request is created or a comment starting with
`/verify` is posted to an existing pull request.

```yaml
# .github/workflows/pull_request.yml
name: Pull Requests
on:
  pull_request:
    types: [opened]
permissions:
  contents: read
  pull-requests: write
jobs:
  pullRequestHandler:
    name: PullRequestHandler
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - name: PullRequestHandler
        uses: ScoopInstaller/GithubActions@main
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

# .github/workflows/issue_commented.yml
name: Commented Pull Request
on:
  issue_comment:
    types: [created]
permissions:
  contents: read
  pull-requests: write
jobs:
  pullRequestHandler:
    name: PullRequestHandler
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - name: PullRequestHandler
        uses: ScoopInstaller/GithubActions@main
        if: startsWith(github.event.comment.body, '/verify')
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Multiple validators are executed for each pull request:

1. JSON standard format check
1. Required properties (`License`, `Description`) are in place
1. Hashes of files are correct
1. Checkver functionality
1. Autoupdate functionality

#### lint-pr-title

The `lint-pr-title` action checks if the title of a pull request follows the
required format. Check [lint-pr-title README](lint-pr-title/README.md) for more details.

### Environment variables

Following environment variables are available for the main action.

```yaml
- uses: ScoopInstaller/GithubActions@main
  env:
    # `GITHUB_TOKEN`: **REQUIRED**
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    # `USER_EMAIL`: Optional
    # `41898282+github-actions[bot]@users.noreply.github.com` if not specified
    USER_EMAIL: ''
    # `SCOOP_REPO`: Optional
    # If specified, scoop config 'scoop_repo' will be configured and scoop updated
    SCOOP_REPO: ''
    # `SCOOP_BRANCH`: Optional
    # If specified, scoop config 'scoop_branch' will be configured and scoop updated
    SCOOP_BRANCH: ''
    # `SKIP_UPDATED`: Optional, `1` to enable
    # If enabled, log of checkver utility will not print latest versions
    SKIP_UPDATED: ''
    # `THROW_ERROR`: Optional, `1` to enable
    # If enabled, error from checkver utility will be thrown as exception and cause the run to fail
    THROW_ERROR: ''
    # `SPECIAL_SNOWFLAKES`: Optional
    # List of manifest names joined with `,` used as parameter for auto-pr utility.
    SPECIAL_SNOWFLAKES: ''
```

Configuration of composable actions can be found in their respective README files
in their subfolders.

## License

The project is released under the [MIT](LICENSE) License.

[ci-badge]: https://github.com/ScoopInstaller/GithubActions/actions/workflows/ci.yml/badge.svg
[ci-url]: https://github.com/ScoopInstaller/GithubActions/actions/workflows/ci.yml
[release-badge]: https://img.shields.io/github/v/release/ScoopInstaller/GithubActions
[releases]: https://github.com/ScoopInstaller/GithubActions/releases
[license-badge]: https://img.shields.io/github/license/ScoopInstaller/GithubActions
[discord-badge]: https://img.shields.io/badge/chat-on%20discord-7289DA.svg
[discord-url]: https://discord.gg/s9yRQHt
[ScoopInstaller/BucketTemplate]: https://github.com/ScoopInstaller/BucketTemplate
