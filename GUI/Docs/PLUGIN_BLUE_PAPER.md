# Plugin Development Blue Paper

> **Status:** Draft · **Target:** MiMiNavigator 1.x · **Author:** Iakov Senatov

---

## Overview

MiMiNavigator aims to support a two-tier plugin architecture that balances power, safety, and ease of authoring. This document outlines the design principles, plugin categories, API surface, security model, and recommended implementation path.

---

## Design Principles

1. **Plugins must never compromise host stability.** A crashing or misbehaving plugin must not bring down MiMiNavigator.
2. **Zero-trust by default.** Plugins receive only the capabilities they declare; everything else is denied.
3. **Hot-reload where possible.** Lightweight (Tier 2) plugins reload without restarting the app.
4. **Native first.** The primary plugin language is Swift; scripting is a secondary convenience layer.

---

## Tier 1 — Swift Package Plugins

Full-power plugins compiled as Swift Packages. Suitable for archive format providers, custom columns, SFTP/cloud providers, and deep UI integrations.

### Plugin Protocol

```swift
// MiMiPluginKit/Sources/MiMiPluginKit/MiMiPlugin.swift

public protocol MiMiPlugin: Sendable {
    /// Reverse-DNS identifier, e.g. "com.example.git-status"
    var id: String { get }

    /// Human-readable name shown in Settings → Plugins
    var name: String { get }

    /// SemVer string
    var version: String { get }

    /// Declared capabilities — the host grants access only for these
    var capabilities: Set<PluginCapability> { get }

    /// Called once when the plugin is loaded
    func activate(context: PluginContext) async throws

    /// Called on shutdown or when the user disables the plugin
    func deactivate() async
}
```

### Capabilities

```swift
public enum PluginCapability: String, Sendable, CaseIterable {
    case contextMenuItem    // inject items into the right-click menu
    case columnProvider     // add a custom column to the file table
    case filePreview        // provide a preview for MediaInfoPanel
    case toolbarAction      // add a button to the toolbar
    case fileTransformer    // batch rename, convert, watermark, etc.
    case archiveFormat      // register a new archive format for VFS browsing
    case protocolProvider   // register a remote filesystem protocol (WebDAV, S3, …)
}
```

### Plugin Context

The host exposes a sandboxed context object — the **only** way a plugin interacts with the app:

```swift
public struct PluginContext: Sendable {
    /// Currently selected files in the focused panel
    let selectedFiles: @Sendable () -> [URL]

    /// Current directory of the focused panel
    let currentDirectory: @Sendable () -> URL

    /// Navigate the focused panel to a URL
    let navigate: @Sendable (URL) async -> Void

    /// Show an alert to the user
    let showAlert: @Sendable (String, String) -> Void

    /// Register a context-menu item
    let registerMenuItem: @Sendable (PluginMenuItem) -> Void

    /// Register a custom table column
    let registerColumn: @Sendable (PluginColumn) -> Void

    /// Log through the host's LogKit
    let log: @Sendable (PluginLogLevel, String) -> Void
}
```

### Custom Column Example

```swift
public struct PluginColumn: Sendable {
    let id: String           // unique, e.g. "git-status"
    let title: String        // shown in column header
    let width: CGFloat       // default width in points

    /// Called per-row. Must be fast (< 1 ms) or return a cached value.
    let value: @Sendable (URL) -> String
}
```

### Context Menu Item Example

```swift
public struct PluginMenuItem: Sendable {
    let title: String
    let icon: String?                          // SF Symbol name
    let shortcut: String?                      // e.g. "⌘⇧G"
    let isEnabled: @Sendable ([URL]) -> Bool   // gray-out logic
    let action: @Sendable ([URL]) async -> Void
}
```

### Loading Mechanism

Tier 1 plugins are compiled Swift Packages. Two loading strategies:

| Strategy | Pros | Cons |
|----------|------|------|
| **Static link** (Package dependency) | Full type safety, zero overhead | Requires app rebuild |
| **Dynamic bundle** (`Bundle.load()`) | Load at runtime from `~/.mimi/plugins/` | Fragile ABI, signing issues |

**Recommended for v1:** static linking via `Package.swift` dependency. Dynamic bundles can follow once the protocol stabilizes.

---

## Tier 2 — Script Plugins (JavaScriptCore)

Lightweight plugins authored in JavaScript. No Xcode required — drop a `.js` file into `~/.mimi/plugins/` and it loads on next launch (or hot-reloads on file change).

### Why JavaScriptCore

- Ships with macOS — zero dependencies
- Sandboxed by default — no filesystem access unless the host grants it
- Fast startup (< 5 ms per plugin)
- Familiar language for a wide contributor base

### Script Plugin Structure

```javascript
// ~/.mimi/plugins/git-status.js

plugin = {
    id:           "com.example.git-status",
    name:         "Git Status Column",
    version:      "1.0.0",
    capabilities: ["columnProvider"]
};

// Called by the host for each directory row
function columnValue(filePath) {
    // host.exec() is the only way to run shell commands —
    // sandboxed, audited, timeout-limited
    var result = host.exec("git status --porcelain -- " + filePath);
    if (result.startsWith("M"))  return "modified";
    if (result.startsWith("?"))  return "untracked";
    if (result.startsWith("A"))  return "added";
    return "";
}

// Called by the host for context-menu plugins
function menuItems() {
    return [
        {
            title: "Copy Git Hash",
            icon:  "doc.on.clipboard",
            action: function(files) {
                var hash = host.exec("git log -1 --format=%H -- " + files[0]);
                host.copyToClipboard(hash.trim());
            }
        }
    ];
}
```

### Host API Exposed to Scripts

```javascript
host.exec(command)              // run shell command (sandboxed, audited)
host.readFile(path)             // read file contents (only within allowed dirs)
host.selectedFiles()            // array of selected file paths
host.currentDirectory()         // current panel directory
host.navigate(path)             // navigate panel to path
host.copyToClipboard(text)      // copy string to pasteboard
host.showAlert(title, message)  // show alert dialog
host.log(level, message)        // write to MiMiNavigator log
```

### Swift-Side Integration

```swift
import JavaScriptCore

final class ScriptPluginLoader {
    private let context = JSContext()!

    func load(from url: URL) throws {
        let source = try String(contentsOf: url, encoding: .utf8)

        // Inject sandboxed host API
        context.setObject(HostBridge.self,
                          forKeyedSubscript: "host" as NSString)

        context.evaluateScript(source)

        // Read plugin descriptor
        guard let descriptor = context.objectForKeyedSubscript("plugin"),
              let id = descriptor.objectForKeyedSubscript("id")?.toString()
        else {
            throw PluginError.invalidDescriptor(url)
        }

        log.info("[Plugins] loaded script plugin: \(id)")
    }
}
```

---

## Security Model

### Sandbox Levels

Every plugin — Swift or JavaScript — operates under a declared sandbox:

```swift
public struct PluginSandbox: Sendable {
    /// Directories the plugin may access (current dir + selected files by default)
    let allowedPaths: [URL]

    /// Permitted file operations
    let allowedOperations: Set<FileOperation>  // .read, .write, .execute

    /// Whether outbound network is permitted
    let networkAllowed: Bool                   // false by default

    /// Memory ceiling (the host terminates plugins that exceed it)
    let maxMemoryMB: Int                       // 256 by default

    /// Per-call timeout (protects against infinite loops in scripts)
    let timeoutSeconds: TimeInterval           // 30 by default
}
```

### Trust Tiers

```swift
public enum PluginTrust: Sendable, Comparable {
    /// Shipped inside the app bundle — full trust
    case builtin

    /// Signed with a Developer ID — trusted after first-run consent
    case signed

    /// Unsigned community plugin — requires explicit user approval per capability
    case community
}
```

### Audit Trail

All plugin file-system and shell operations are logged through LogKit:

```
[Plugin:com.example.git-status] exec "git status --porcelain -- /Users/senat/file.txt" → 0 (12ms)
[Plugin:com.example.git-status] readFile "/Users/senat/.gitignore" (412 bytes)
```

### Crash Isolation

| Tier | Isolation |
|------|-----------|
| Tier 1 (Swift) | Runs in-process. A crash takes down the host. Mitigated by code review + signing. |
| Tier 1 (XPC, future) | Separate process. Crash is caught, plugin auto-restarts. |
| Tier 2 (JS) | JavaScriptCore sandbox. Exceptions are caught; the host disables the plugin and logs the error. |

---

## Plugin Lifecycle

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│  Discover    │────▶│   Validate   │────▶│  Activate   │
│  ~/.mimi/    │     │  signature   │     │  plugin     │
│  plugins/    │     │  + manifest  │     │  .activate()│
└─────────────┘     └──────────────┘     └─────┬──────┘
                                               │
                          ┌────────────────────┘
                          ▼
                    ┌────────────┐     ┌──────────────┐
                    │  Running    │────▶│  Deactivate   │
                    │  (handles   │     │  on quit /    │
                    │   events)   │     │  user toggle  │
                    └────────────┘     └──────────────┘
```

### Discovery

On launch, the host scans:
1. `Packages/` — compiled Swift plugins (Tier 1)
2. `~/.mimi/plugins/*.js` — script plugins (Tier 2)
3. `~/.mimi/plugins/*.bundle` — dynamic Swift bundles (Tier 1, future)

### Settings UI

`Settings → Plugins` pane lists all discovered plugins with:
- Enable / Disable toggle
- Trust level badge (builtin / signed / community)
- Declared capabilities
- "Reveal in Finder" button

---

## Recommended Implementation Roadmap

| Phase | Scope | Effort |
|-------|-------|--------|
| **Phase 1** | Create `MiMiPluginKit` package with `MiMiPlugin` protocol, `PluginCapability`, `PluginContext` | 1 week |
| **Phase 2** | Implement `columnProvider` capability — one built-in plugin ("Git Status") as proof of concept | 1 week |
| **Phase 3** | Implement `contextMenuItem` capability — "Copy Git Hash", "Open in VS Code" | 3 days |
| **Phase 4** | JavaScriptCore loader for Tier 2 scripts, `host.*` bridge API | 1 week |
| **Phase 5** | Settings → Plugins pane, sandbox enforcement, audit logging | 1 week |
| **Phase 6** | Dynamic `Bundle.load()` support for Tier 1 plugins (optional) | 2 weeks |

---

## Example Plugin Ideas

| Plugin | Tier | Capability |
|--------|------|------------|
| Git Status column | 2 (JS) | `columnProvider` |
| Upload to S3 | 2 (JS) | `contextMenuItem` |
| RAR 5 archive support | 1 (Swift) | `archiveFormat` |
| WebDAV filesystem | 1 (Swift) | `protocolProvider` |
| EXIF batch editor | 1 (Swift) | `fileTransformer` |
| Markdown preview | 2 (JS) | `filePreview` |
| Checksum verifier | 2 (JS) | `contextMenuItem` |
| Batch watermark | 1 (Swift) | `fileTransformer` |

---

## Open Questions

1. **Should Tier 1 plugins use XPC from day one?** XPC provides crash isolation but adds complexity. Starting in-process with a migration path to XPC seems pragmatic.
2. **Plugin dependency management.** Should script plugins be allowed to declare npm-style dependencies, or keep them single-file?
3. **UI contributions beyond columns and menus.** Should plugins be able to inject entire SwiftUI views (e.g., a sidebar widget)? This requires careful API design to avoid layout breakage.
4. **Plugin marketplace.** A curated `awesome-mimi-plugins` GitHub repo may be sufficient for the early community.

---

*This document is a living draft. Feedback and pull requests are welcome.*
