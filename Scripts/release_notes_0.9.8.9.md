# MiMiNavigator v0.9.8.9

## Google Drive share links
- **Persistent OAuth token cache**: access/refresh tokens are cached in `~/.mimi/google_drive_token_cache.json`; Keychain is only a fallback
- **Fewer password prompts**: valid cached access tokens are reused until expiration instead of reading Keychain on every share action
- **Blog-friendly image links**: image share links now use `https://lh3.googleusercontent.com/d/<fileID>=s0` instead of Drive preview/download URLs
- **Folder/file fallback order**: folders keep Drive folder URLs, non-image files prefer content links before preview links

## Media info
- **Photo Date vs file dates**: EXIF photo date is shown separately from filesystem `File Created` / `File Modified`
- **OneDrive/cloud date clarity**: local cloud placeholder creation dates no longer look like camera capture dates
- **Spotlight metadata fallback**: sparse JPEGs now show available Spotlight fields such as Date Added, upload state, logical/physical size, pixel count, bit depth, alpha, and orientation

## UI polish
- **Media Convert button**: brighter primary-style Convert button in the Media Info panel

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.8.8...v0.9.8.9
