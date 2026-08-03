# lint-pr-title

Validate that pull request titles follow the [Scoop naming convention](https://github.com/ScoopInstaller/.github/blob/main/.github/CONTRIBUTING.md#for-scoop-buckets).

## Usage

```yaml
name: Lint Pull Request

on:
  pull_request:
    types: [opened, edited, synchronize]

permissions:
  pull-requests: read

jobs:
  pr-title:
    name: Validate PR Title
    runs-on: ubuntu-latest
    steps:
      - name: Check PR Title
        uses: ScoopInstaller/GithubActions/lint-pr-title@main
```

## Valid title formats

```text
app-name: Add version 1.0
app-name@1.0: fix download url
app-name(*): update multiple manifests
app-name(-beta): update app-name and app-name-beta manifests
(chore): update CI config
```

## Rules

- **New manifest:** `<manifest-name>: Add version <version>`
- **Manifest update:** `<manifest-name>@<version>: <description>`
- **Multi-manifest:** `<manifest-name>(*): <description>` or `<manifest-name>(<suffix>): <description>`
- **Maintenance:** `(chore): <description>`
- Manifest names must use **lowercase letters**, **numbers**, **hyphens**, and **dots** only
- Manifest names must not start with a hyphen or dot
- Manifest names must not end with a dot
- Parenthesized portion content must use **lowercase letters**, **numbers**, **hyphens**, and **dots** only, and must contain at least one letter or number
- Parenthesized portion content may start with a hyphen or dot, but must not end with a dot
- The parenthesized portion is only appropriate when the PR's diff involves **multiple manifests** (not enforced by this action)
- `(*)` wildcard and `@version` are mutually exclusive
