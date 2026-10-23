# MiMiNavigator v0.9.1.2

This release improves archive reliability and file-panel responsiveness. It starts the four-component version sequence; each component after the major version runs from 0 through 9 before carrying to the left.

## Highlights

- Open TAR and TAR.GZ archives with the options supported by macOS tar. Extraction errors are reported instead of showing an empty archive.
- Repack changed archives into a separate file, verify it, and replace the original only after verification succeeds. Hidden files are included.
- Keep the extracted archive open and show an error if repacking fails, so changes remain available for another attempt.
- Navigate large folders more smoothly by updating visible rows incrementally; column autofit also stays within narrow panels.
- Show Count and Permissions columns only where their data is meaningful, including File Provider locations.
- Detect this four-component release as an update from the earlier three-component release and legacy five-component builds.

## Validation

- ArchiveKit tests cover TAR and TAR.GZ extraction, ZIP/TAR repacking, hidden files, empty ZIP files, and failure recovery.
- The application was built from local source-free MiMiKits binaries with a macOS 26 deployment target.
- In the running Debug app, modified ZIP contents were saved and an unsupported GZ repack left the original and extracted files intact.

## Download

For Apple silicon Macs running macOS 26 or later. Open the signed and notarized DMG and drag MiMiNavigator to Applications.

**Full Changelog**: https://github.com/senatov/MiMiNavigator/compare/v0.9.1...v0.9.1.2
