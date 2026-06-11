# MiMiNavigator v0.9.9.5.3

Cloud Share+Link update for Google Drive and Dropbox.

## Highlights

- Share+Link now detects mounted Google Drive and Dropbox accounts and offers a provider choice when both are available.
- Google Drive keeps view-only and editable sharing modes, while Dropbox exposes the supported view-only action.
- Dropbox sharing uses OAuth PKCE with refresh tokens stored in Keychain and copies items into the Dropbox `Public` folder before creating a shared link.
- Generated cloud links are shortened to branded `https://spoo.me/MiMiNavigator_XX` URLs and copied directly to the clipboard.

## Fixed

- Missing Google Drive and Dropbox `Public` folders are created automatically when the mounted drive is writable.
- Dropbox shared-link creation waits for newly copied files to finish syncing before requesting the remote link.
- Dropbox OAuth no longer waits indefinitely when authorization cannot return a callback.
- Existing filenames in Dropbox `Public` are preserved by generating a collision-safe destination name.
- Long provider URLs are no longer copied when branded short-link creation fails.
- Temporary shortener failures and alias collisions are retried with a fresh alias.

## Security

- Dropbox authorization uses PKCE without embedding an app secret.
- Dropbox refresh tokens are stored in the macOS Keychain.

## Documentation

- Release metadata updated to version `0.9.9.5.3`, build `123`.

## Download

The DMG is signed, notarized by Apple, and includes an Applications shortcut for drag-to-install.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.9.5.2...v0.9.9.5.3
