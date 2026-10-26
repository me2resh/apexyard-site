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
| Change the edge function to pass /install through | Key `install`, no rename. | Change in another repository; production needs the same change. |
| Do nothing until the release | No work now. | The serving setup is not tested. The production change is large. |

## Decision

Chosen: **serve the file from this repository**, because the site controls the bytes, the content type and the cache.

1. `install` is the framework `install.sh`, unchanged. `install.source` records the repository, the commit and the SHA-256.
2. The S3 key is `install.html`. The CloudFront viewer-request function rewrites each path without a file extension to `<path>.html`, so /install reads the key `install.html`. The function lives in the infrastructure repository. The staging workflow excludes `install`, `install.html` and `install.source` from the bulk sync. A separate `aws s3 cp` publishes the repo file `install` to that key with `Content-Type: text/plain; charset=utf-8` and `Cache-Control: max-age=300`. The AWS CLI guesses a type from the file name. The copy sets the type.
3. The production workflow excludes `install`, `install.html` and `install.source` from each sync. It does not publish /install.
4. `.github/tests/test-install-path.sh` checks the SHA-256, the staging type and cache, and the production exclusion.
5. For production, a later change replaces `install` with the stamped script from the tagged release and updates `install.source`. The test then pins the new checksum. The production workflow gets the same `aws s3 cp` to the key `install.html`, or the edge function changes so the key can stay `install`. Every sync that writes the bucket in `deploy-staging-v2.yml`, `deploy-aws.yml`, `deploy-aws-staging.yml` and `preview-deploy.yml` excludes `install`, `install.html` and `install.source`.

## Consequences

- Production serves no /install until the release change merges.
- The staging copy is the unstamped `dev` script. Do not use it as a release installer.
- A person updates `install.source` and `install` together. The test fails if they differ.
- /install.html also serves the script.
- Staging returns 401 without credentials. A smoke test needs credentials.
- The production change uses the key `install.html`, or a function change.

## Artifacts

- `install`
- `install.source`
- `.github/tests/test-install-path.sh`
- `.github/workflows/deploy-staging-v2.yml`
- `.github/workflows/deploy-aws.yml`
- `.github/workflows/deploy-aws-staging.yml`
- `.github/workflows/preview-deploy.yml`
