# Persistent Cache Architecture

MiMiNavigator uses a two-level cache for expensive values that can always be reconstructed.

## Storage levels

### L1: process memory

Only actively used values remain in actors or bounded `NSCache` instances. L1 avoids SQLite access while a panel repeatedly renders the same directory. It is deliberately small and is discarded when navigation moves outside the nearby history context.

### L2: CacheKit and SQLite

`CacheKit` stores opaque payloads in:

```text
~/Library/Caches/MiMiNavigator/cache.sqlite
```

The database uses GRDB, SQLite WAL journaling, namespace-specific keys, expiry dates, last-access timestamps, cost accounting, and schema migrations. L2 survives normal application restarts but remains disposable because macOS may purge `Library/Caches`.

`/tmp` is reserved for session-only working data such as extracted archives and conversion intermediates. It is not used for persistent indexes because the operating system may remove it at any time.

## Namespaces

### `directory-size-v1`

- Key: normalized resolved directory path.
- Payload: encoded size, directory modification time, and last L1 access.
- Validation: the current directory modification time must equal the cached value.
- L1 policy: nearby paths around the current history position, 30-minute idle limit, 512 entries.
- L2 policy: nearby history prefixes, seven-day lifetime, 4,096 entries, 16 MiB cost limit.
- Migration: the legacy `dirsize.cache` JSON snapshot is imported idempotently; it is removed only after every entry is written successfully.

### `file-content-sha256-v1`

- Key: normalized resolved file path.
- Payload: SHA-256 digest, file size, and modification time.
- Validation: size and modification time are checked before every reuse.
- Hashing: files are streamed in 1 MiB chunks instead of being loaded wholly into memory.
- Policy: 30-day idle/lifetime window, 4,096 entries, 8 MiB cost limit.

Conflict comparison computes source and destination hashes concurrently. A later comparison can reuse a digest across sessions when file identity metadata remains unchanged.

## Invalidation rules

A cache miss, expired row, metadata mismatch, disconnected volume, unreadable file, or removed database must fall back to normal computation. Cache failures are logged but never make file operations fail. User content, credentials, operation state, and configuration must not be stored in CacheKit.

## Maintenance

Namespace names include a schema version. Change the suffix when payload compatibility cannot be maintained. Database schema changes use GRDB migrations. Add a bounded pruning policy for every new namespace and include its expected validation keys in this document.
