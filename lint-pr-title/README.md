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
(chore): update CI config
```

## Rules

- **New manifest:** `<manifest-name>: Add version <version>`
- **Manifest update:** `<manifest-name>@<version>: <description>`
- **Multi-manifest wildcard:** `<manifest-name>(*): <description>`
- **Maintenance:** `(chore): <description>`
- Manifest names must use **lowercase letters**, **numbers**, **hyphens**, and **dots** only
- Manifest names must not start with a hyphen or dot
- Manifest names must not end with a dot
- `(*)` wildcard and `@version` are mutually exclusive
