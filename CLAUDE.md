# Anytype iOS App

## Overview
Anytype is a privacy-focused, local-first workspace application for iOS. Built with Swift and SwiftUI, it provides users with a secure environment for creating and organizing their digital content. The app uses a custom middleware for data synchronization and storage.

## ⚠️ CRITICAL RULES - NEVER VIOLATE
1. **NEVER commit/stage without explicit user request** - Wait for user to explicitly ask
2. **NEVER add AI signatures in code** - No AI attribution comments or markers in source files
3. **NEVER run destructive git operations** without explicit approval (`--amend`, `reset --hard`, `push --force`, `clean -fd`)
4. **Always present action plan** before implementing multi-step changes and await approval


## 🎯 Core Guidelines

### Code Quality
- **Never use hardcoded strings in UI** - Use `Loc.yourKey` constants
- **Never push directly to develop/main** - Always use feature branches
- **Remove unused code after refactoring** - Delete unreferenced properties, functions, files


### Code Change Principles
- **Read before edit** - Always read the full file/context before making changes
- **Minimize diffs** - Prefer the smallest change that solves the problem
- **Investigate before diagnosing** - Understand the actual issue, don't guess
- **No speculative fallbacks** - Don't add error handling for scenarios that can't happen


## ⚠️ Common Mistakes

**Autonomous Committing (2025-01-28)**: Committed without explicit user request. NEVER commit unless user explicitly asks.

**Over-Engineering (pattern)**: Adding "defensive" code, extra abstractions, or configurability that wasn't requested. Three similar lines > premature abstraction. Only validate at system boundaries.

**Guessing Before Reading (pattern)**: Making assumptions about code behavior without reading it first. Always read the file before suggesting changes.

**Remember**: This file is a quick reference. For detailed guidance, read the relevant skill or specialized guide.
