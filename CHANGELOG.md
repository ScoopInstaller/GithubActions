# Changelog

## [3.0.0](https://github.com/ScoopInstaller/GithubActions/compare/v2.0.0...v3.0.0) (2026-08-22)


### Features

* Add `SCOOP_REPO` configuration option ([#25](https://github.com/ScoopInstaller/GithubActions/issues/25)) ([414a2ff](https://github.com/ScoopInstaller/GithubActions/commit/414a2ff833901045a1a6565ed4c3706f0c0b267e))
* Add lint checks ([#61](https://github.com/ScoopInstaller/GithubActions/issues/61)) ([499cffb](https://github.com/ScoopInstaller/GithubActions/commit/499cffb3c2cd98a5847890270c96d9c7c375e576))
* add support for repository_dispatch event ([#60](https://github.com/ScoopInstaller/GithubActions/issues/60)) ([c92396e](https://github.com/ScoopInstaller/GithubActions/commit/c92396e80eae6ef076cb65b4b53e8729688e03f5))
* add token input and use default username constant ([#95](https://github.com/ScoopInstaller/GithubActions/issues/95)) ([3a5a517](https://github.com/ScoopInstaller/GithubActions/commit/3a5a517f545514bd6f63ecde02ebf1640206d0d9))
* Change label `help-wanted` to `help wanted` ([78829ef](https://github.com/ScoopInstaller/GithubActions/commit/78829ef391e2f142a574ee45127ae45e110c6f9d))
* **issue-prpost:** Commit message is now full PR Title (with version) ([d84ea47](https://github.com/ScoopInstaller/GithubActions/commit/d84ea471f505f077240379356359872480702e06))
* **issue.hash:** Do not compare pr title with case sensitive ([3a1a90e](https://github.com/ScoopInstaller/GithubActions/commit/3a1a90e3a2a8d214527805c91328811abd92464a))
* **lint-pr-title:** add action to validate PR titles ([#82](https://github.com/ScoopInstaller/GithubActions/issues/82)) ([a709983](https://github.com/ScoopInstaller/GithubActions/commit/a709983c0692a8a853c288cf5e9bf14658107936))
* Provide help tips for decompress error issues ([#62](https://github.com/ScoopInstaller/GithubActions/issues/62)) ([25a6ee4](https://github.com/ScoopInstaller/GithubActions/commit/25a6ee4fcbb3cc22e69173a84f949600aac183b6))
* Provide link to logs in the comment ([#58](https://github.com/ScoopInstaller/GithubActions/issues/58)) ([eb5909d](https://github.com/ScoopInstaller/GithubActions/commit/eb5909d96791094160e228a6b920084ba4cb24c2))
* Support `FORCE_PWSH` configuration option ([#48](https://github.com/ScoopInstaller/GithubActions/issues/48)) ([e0e11bb](https://github.com/ScoopInstaller/GithubActions/commit/e0e11bb5654555e23e5cb8e4e3e14ac415b524a0))
* Support ARM64 ([#24](https://github.com/ScoopInstaller/GithubActions/issues/24)) ([18a642c](https://github.com/ScoopInstaller/GithubActions/commit/18a642c75e563aaf0eba7ad202eab69e7a4a5e56))
* Support checkver's option "THROW_ERROR" ([#5](https://github.com/ScoopInstaller/GithubActions/issues/5)) ([24f1008](https://github.com/ScoopInstaller/GithubActions/commit/24f10081a22578c2a378e01ead79945e6a1a8ed9))
* Support issue title with label ([#54](https://github.com/ScoopInstaller/GithubActions/issues/54)) ([6997d58](https://github.com/ScoopInstaller/GithubActions/commit/6997d58cf750f861bd929ef23950407e85502846))
* Support private repos for PRs checks and fix non-master default branch for scheduled action ([#4](https://github.com/ScoopInstaller/GithubActions/issues/4)) ([62f511a](https://github.com/ScoopInstaller/GithubActions/commit/62f511a48ba1d0c71396bd116f1340aaa5e5d61f))
* Support SCOOP_BRANCH environment variable ([540a906](https://github.com/ScoopInstaller/GithubActions/commit/540a90602d41669feb783c1f90b1c55d2139c95a))


### Bug Fixes

* Apply several fixes ([#39](https://github.com/ScoopInstaller/GithubActions/issues/39)) ([9fa5cad](https://github.com/ScoopInstaller/GithubActions/commit/9fa5cad7cc83cf48cda88dfcbc7799b01d7eec31))
* avoid validation error when issue body is empty ([#80](https://github.com/ScoopInstaller/GithubActions/issues/80)) ([e174c3b](https://github.com/ScoopInstaller/GithubActions/commit/e174c3bef2aeec16a40f2f075cafa167733f0a3e))
* Be consistent with functional naming of PR ([21d3033](https://github.com/ScoopInstaller/GithubActions/commit/21d3033a8b4cff35b3c16071f0f61380969afe8e))
* bugfix and cleanup ([#79](https://github.com/ScoopInstaller/GithubActions/issues/79)) ([ec4ac48](https://github.com/ScoopInstaller/GithubActions/commit/ec4ac4815ee2309cb47a239e66d959cbf8127b56))
* Don't update Scoop if not needed ([#30](https://github.com/ScoopInstaller/GithubActions/issues/30)) ([23a63d8](https://github.com/ScoopInstaller/GithubActions/commit/23a63d8c4d9f2f1f486c75d876590d7f25ff6068))
* format and lint ([#78](https://github.com/ScoopInstaller/GithubActions/issues/78)) ([dfaf4c0](https://github.com/ScoopInstaller/GithubActions/commit/dfaf4c006776de6a4d162f557e5566c75fa3e96c))
* Handle exceptions from checkhashes.ps1 invocation ([#56](https://github.com/ScoopInstaller/GithubActions/issues/56)) ([ff4a9f1](https://github.com/ScoopInstaller/GithubActions/commit/ff4a9f14fcb4dab64865355a75d3f6139b1884b8))
* **hash:** Don't run au.hash check if there are no au.hash ([#29](https://github.com/ScoopInstaller/GithubActions/issues/29)) ([f0cb83a](https://github.com/ScoopInstaller/GithubActions/commit/f0cb83abb816169af735a69920b2433c33d5b4f3))
* **issue:** Handle non-existent manifest ([7abac48](https://github.com/ScoopInstaller/GithubActions/commit/7abac4840cd3bf9c584cd0741d1837dc0c5e7496))
* **IssueHandler:** Keep manifest name casing in posted PR title ([922e27d](https://github.com/ScoopInstaller/GithubActions/commit/922e27d7ebf55ab73cb0ee83de46ff5ca543bcab))
* **issue:** Support non-master default branches ([9b54b96](https://github.com/ScoopInstaller/GithubActions/commit/9b54b962cf6d0e6a30f6b00ed6accde92318873d))
* No need to be so strict with hits to user ([677dc8e](https://github.com/ScoopInstaller/GithubActions/commit/677dc8ee4f0983cd7bb3660342f9c2d6f686d81f))
* **PR:** Remove 'hash' function ([#26](https://github.com/ScoopInstaller/GithubActions/issues/26)) ([d6ee14b](https://github.com/ScoopInstaller/GithubActions/commit/d6ee14b39ce7454dc3629e76208815e7a75520eb))
* Readme ([97b74a5](https://github.com/ScoopInstaller/GithubActions/commit/97b74a5fc8b5e9fa73e4db7953d7ee5b6839d55a))
* **Readme:** Migrate to 'main' branch [scoop skip] ([0dd85e5](https://github.com/ScoopInstaller/GithubActions/commit/0dd85e50852fe0f771fc31a9e67fd03c63aecb19))
* refine hash fixing workflow ([#75](https://github.com/ScoopInstaller/GithubActions/issues/75)) ([6f53ec8](https://github.com/ScoopInstaller/GithubActions/commit/6f53ec8a0e76ae9d352e4982d996edd895bf2f22))
* Remove label `verify` in all cases ([6a95cea](https://github.com/ScoopInstaller/GithubActions/commit/6a95cea1910f7ab301765b9510e72f5ab776eb05))
* restore global ErrorActionPreference override ([#88](https://github.com/ScoopInstaller/GithubActions/issues/88)) ([6b3758d](https://github.com/ScoopInstaller/GithubActions/commit/6b3758d26c6828fda0f9147dc658580678e7573f))
* Set global preferences variables ([#22](https://github.com/ScoopInstaller/GithubActions/issues/22)) ([52a914d](https://github.com/ScoopInstaller/GithubActions/commit/52a914dbf0bde30e42872f7ed012323bc94c6af4))
* Switch to composite instead of node ([#19](https://github.com/ScoopInstaller/GithubActions/issues/19)) ([f5afc1f](https://github.com/ScoopInstaller/GithubActions/commit/f5afc1f4647f48e39709ac7311c4bc56c51d49b8))
* typo ([9b2e745](https://github.com/ScoopInstaller/GithubActions/commit/9b2e745c63a967b097742fc840210f82713ccd8f))
* **typo:** Fix spelling in action message ([#34](https://github.com/ScoopInstaller/GithubActions/issues/34)) ([97c0343](https://github.com/ScoopInstaller/GithubActions/commit/97c03431c3ff0d86ab5f6801caac77c286f3b735))
* Upstream changes of `dl_xxx()` ([#16](https://github.com/ScoopInstaller/GithubActions/issues/16)) ([c4665d4](https://github.com/ScoopInstaller/GithubActions/commit/c4665d45ddde5f5b9f3acbd09a49663dcba87fbc))
* Use 'checkurls.ps1` to check downloading ([#43](https://github.com/ScoopInstaller/GithubActions/issues/43)) ([be232e1](https://github.com/ScoopInstaller/GithubActions/commit/be232e1829a31a567f2fbd1af41fe4612e3b112e))
* Use new config names ([#12](https://github.com/ScoopInstaller/GithubActions/issues/12)) ([16a4337](https://github.com/ScoopInstaller/GithubActions/commit/16a433741e4452c9b90d4a872a40135ad572d045))


### Continuous Integration

* introduce release-please workflow and config ([#83](https://github.com/ScoopInstaller/GithubActions/issues/83)) ([720646f](https://github.com/ScoopInstaller/GithubActions/commit/720646f3a790879c1e6849fc700bea99a0d00766))
