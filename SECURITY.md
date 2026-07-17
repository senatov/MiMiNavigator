# Security Policy

## Supported Versions

MiMiNavigator is under active development. Security fixes are provided for the
latest release only. Users should upgrade to the newest version available on
the [Releases page](https://github.com/senatov/MiMiNavigator/releases).

| Version | Supported |
| --- | --- |
| Latest release | Yes |
| Older releases | No |

## Reporting a Vulnerability

Please report suspected vulnerabilities privately. Do not open a public GitHub
issue, discussion, or pull request containing vulnerability details, credentials,
tokens, private file paths, personal data, or proof-of-concept code.

Use one of these channels:

1. GitHub's **Report a vulnerability** option on the repository's
   [Security page](https://github.com/senatov/MiMiNavigator/security), if it is
   available.
2. Email [senatov@icloud.com](mailto:senatov@icloud.com) with the subject
   `MiMiNavigator security report`.

Include as much of the following information as possible:

- the affected MiMiNavigator version and macOS version;
- a clear description of the issue and its security impact;
- steps needed to reproduce it, including a minimal proof of concept if useful;
- whether exploitation requires a specially crafted file, archive, network
  service, cloud account, or user interaction;
- any suggested mitigation or fix;
- how you would like to be credited, or whether you prefer to remain anonymous.

Remove or redact passwords, OAuth tokens, private keys, personal files, and
other secrets from the report. If sensitive test data is essential, ask for a
safe way to provide it before sending it.

You should receive an acknowledgement within 7 days. After validation, the
maintainer will share the current assessment and coordinate a fix and disclosure
timeline when appropriate. If the report is not considered a vulnerability, an
explanation will be provided. Please allow reasonable time for a fix to be
released before publishing details.

## Scope

Security reports may include, but are not limited to:

- unintended file access, modification, deletion, or permission changes;
- path traversal or archive extraction outside the selected destination;
- unsafe handling of untrusted filenames, archives, URLs, or remote content;
- command or argument injection into external tools;
- exposure of credentials, OAuth tokens, Keychain data, or sensitive log data;
- insecure update, download, signature, or integrity verification;
- authentication or authorization flaws in cloud and remote-server features.

General bugs, feature requests, and usability problems without a security impact
should be reported through [GitHub Issues](https://github.com/senatov/MiMiNavigator/issues).

## Responsible Disclosure

Please act in good faith: test only with data and systems you own or are
authorized to use, avoid privacy violations and service disruption, and do not
retain or share data obtained during testing. The project will make a reasonable
effort to credit reporters who follow this policy and request acknowledgement.
