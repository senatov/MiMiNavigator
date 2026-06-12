# Cloud Share+Link Developer Notes

## Scope

MiMiNavigator supports API-backed publishing for Google Drive and Dropbox. Both providers produce a provider-owned shared URL and pass it to the common `CloudLinkShortener`.

The feature is intentionally narrow. MiMiNavigator remains a filesystem-first application and does not treat provider APIs as general remote filesystems.

## Service Flow

### Google Drive

1. Authenticate with the configured Google Desktop OAuth client.
2. Ensure the remote `Public` folder exists.
3. Upload the selected file or directory.
4. Apply view-only or editable public permission.
5. Resolve the provider share URL.
6. Shorten and copy the branded URL.

### Dropbox

1. Authenticate with OAuth PKCE.
2. Resolve or create the mounted `Public` folder.
3. Copy the selected item to a collision-safe local destination.
4. Wait for Dropbox to synchronize and index the remote path.
5. Resolve or create a view-only shared URL.
6. Shorten and copy the branded URL.

## Alias Contract

`CloudLinkShortener` is shared by both providers and generates aliases in this format:

```text
mimiNavi<8 random Base62 characters>
```

Example:

```text
https://spoo.me/mimiNavi5Jzui456
```

The suffix alphabet is:

```text
abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789
```

spoo.me limits custom aliases to 16 characters. The 8-character `mimiNavi` prefix plus an 8-character Base62 suffix uses the full limit and provides approximately 48 bits of random alias space. Do not replace the suffix with counters, timestamps, filenames, short UUID prefixes, or another predictable value.

Keep punctuation out of the suffix. Characters such as `!` may be legal in some URL contexts but introduce escaping and interoperability risks in clipboard, browser, messaging, and API paths.

## Failure Handling

The shortener retries these failures with a fresh alias:

- Alias conflict responses.
- HTTP 429 rate limiting.
- HTTP 5xx temporary service failures.

Other service rejections fail immediately and are reported through the Share+Link progress panel.

## Credential Storage

Google Drive uses application OAuth credentials from the bundled or local configuration and stores runtime user tokens outside project files.

Dropbox uses PKCE without an embedded app secret. Its refresh token is stored in macOS Keychain under the MiMiNavigator Dropbox service.

Never log access tokens, refresh tokens, authorization codes, PKCE verifiers, or OAuth client secrets.

## Regression Coverage

`MiMiNavigatorTests.testCloudLinkAliasesAreLongRandomAndURLSafe` generates 1,000 aliases and verifies:

- Every alias starts with `mimiNavi`.
- Every alias has an 8-character suffix and a 16-character total length.
- Every suffix contains only Base62 characters.
- The generated sample contains no duplicates.

Provider integration still requires manual validation with mounted desktop clients and valid OAuth accounts. Unit tests must not create real public short links because doing so leaves external service state behind.
