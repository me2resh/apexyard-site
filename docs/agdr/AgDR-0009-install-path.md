# AgDR-0009: Serve the install script as plain text at /install

- **Status:** Accepted
- **Date:** 2026-10-26
- **Decision owners:** ApexYard maintainers
- **Related:** GH-100, AgDR-0004 (staging overlay)

> In the context of the one-command install, facing a need to give users a short URL for the install script, I decided to serve the framework install.sh as plain text at the extensionless path /install, on staging now and on production with the stamped release script, pinned by checksum, to achieve a URL that works with `curl` and a tested serving setup, accepting that production waits for a tagged framework release.

## Context

- The one-command install is `curl -fsSL <url> | sh`. The URL must return the script text. It must not return HTML. It must not redirect.
- The framework script on the `dev` branch holds the placeholder `__VERSION__`. A release process stamps the real version. The production file must be the stamped script from a tagged release.
- The owner decided that https://apexyard.ai/install waits until a framework release with the CLI assets is tagged.
- The staging site is the place to test the serving setup first.

## Options Considered

| Option | Pros | Cons |
| --- | --- | --- |
| Redirect /install to the raw file on GitHub | No file in this repository. | The redirect adds a hop. The user trusts a branch URL that can change. The site cannot set the content type or the cache. The redirect target is a GitHub path that the site does not control. |
| Serve the file from this repository at /install | One host. The site sets the content type and the cache. A checksum pins the content. | The file is a copy. A person must update it for each release. |
| Do nothing until the release | No work now. | The serving setup is not tested. The production change is large. |

## Decision

Chosen: **serve the file from this repository**, because the site controls the bytes, the content type and the cache.

1. `install` is the framework `install.sh`, unchanged. `install.source` records the repository, the commit and the SHA-256.
2. The staging workflow excludes `install` and `install.source` from the bulk sync. A separate `aws s3 cp` publishes `install` with `Content-Type: text/plain; charset=utf-8` and `Cache-Control: max-age=300`. S3 cannot guess a type for a path with no extension, so the copy sets it.
3. The production workflow excludes both files from each sync. It does not publish /install.
4. `.github/tests/test-install-path.sh` checks the SHA-256, the staging type and cache, and the production exclusion.
5. For production, a later change replaces `install` with the stamped script from the tagged release and updates `install.source`. The test then pins the new checksum. The production workflow gets the same `aws s3 cp` step and drops the exclusion.

## Consequences

- Production serves no /install until the release change merges.
- The staging copy is the unstamped `dev` script. Do not use it as a release installer.
- A person updates `install.source` and `install` together. The test fails if they differ.
- The staging CloudFront distribution must pass the extensionless path to S3 with no rewrite to HTML. The staging deploy shows if it does not.

## Artifacts

- `install`
- `install.source`
- `.github/tests/test-install-path.sh`
- `.github/workflows/deploy-staging-v2.yml`
- `.github/workflows/deploy-aws.yml`
