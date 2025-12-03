# Contributing to MiMiNavigator

Thank you for your interest in contributing to MiMiNavigator! This document provides guidelines and information for contributors.

## Table of Contents

- [Development Setup](#development-setup)
- [Code Quality](#code-quality)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Code Style](#code-style)
- [Testing](#testing)
- [Documentation](#documentation)

## Development Setup

### Requirements

- **macOS**: 15.0 (Sequoia) or later
- **Xcode**: 16.1 or later (with Swift 5.10 support)
- **Git**: Latest stable version

### Getting Started

```bash
# Clone the repository
git clone https://github.com/senatov/MiMiNavigator.git
cd MiMiNavigator

# Open in Xcode
open MiMiNavigator.xcodeproj
```

### Build & Run

**Using Xcode:**
1. Open `MiMiNavigator.xcodeproj`
2. Select the `MiMiNavigator` scheme
3. Press `⌘R` to build and run

**Using Command Line:**
```bash
# Debug build
./Scripts/build_debug.zsh

# Or manually with xcodebuild
xcodebuild -scheme MiMiNavigator \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Build logs are automatically saved to `build-logs/` directory.

## Code Quality

We use several tools to maintain high code quality. All checks run automatically in CI, but you should run them locally before submitting:

### SwiftLint

Enforces Swift style and conventions:

```bash
# Check for issues
swiftlint lint

# Strict mode (recommended before PR)
swiftlint lint --strict

# Auto-fix some issues
swiftlint autocorrect
```

Configuration: `.swiftlint.yml`

### Swift-format

Automatic code formatting:

```bash
# Check formatting
swift-format lint --recursive Gui/Sources

# Format code
swift-format format --in-place --recursive Gui/Sources
```

Configuration: `.swift-format`

### Periphery

Detects unused code:

```bash
# Scan for unused code
periphery scan --config .periphery.yml

# Generate baseline
periphery scan --config .periphery.yml --baseline .periphery_baseline.json
```

Configuration: `.periphery.yml`

### Pre-commit Checklist

Before committing, ensure:

- [ ] Code builds without warnings
- [ ] SwiftLint passes without errors
- [ ] Swift-format check passes
- [ ] No unused code detected by Periphery
- [ ] Tests pass (if applicable)
- [ ] Documentation is updated

## Commit Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, whitespace)
- `refactor`: Code refactoring without functional changes
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (dependencies, tools)
- `ci`: CI/CD changes
- `revert`: Reverting previous commits

### Scope (optional)

Examples: `file-panel`, `navigation`, `ui`, `state`, `scanner`

### Examples

```
feat(file-panel): add multi-selection support

Implements shift-click and command-click selection modes
for multiple file operations.

Closes #42

---

fix(navigation): resolve breadcrumb path update issue

Breadcrumb was not updating when navigating via keyboard.
Added proper state synchronization.

Fixes #38

---

docs: update README with new installation steps

---

refactor(state): extract file scanner to dedicated actor

Improves concurrency and reduces main thread blocking.
```

### Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor" not "Moves cursor")
- First line max 72 characters
- Reference issues/PRs when relevant
- Write in English
- Be clear and descriptive

## Pull Request Process

1. **Fork** the repository

2. **Create a feature branch**
   ```bash
   git checkout -b feat/amazing-feature
   # or
   git checkout -b fix/critical-bug
   ```

3. **Make your changes**
   - Follow the code style guidelines
   - Add tests if applicable
   - Update documentation

4. **Run quality checks**
   ```bash
   swiftlint lint --strict
   swift-format lint --recursive Gui/Sources
   periphery scan --config .periphery.yml
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat(scope): description"
   ```

6. **Push to your fork**
   ```bash
   git push origin feat/amazing-feature
   ```

7. **Open a Pull Request**
   - Use a clear title following commit guidelines
   - Provide detailed description of changes
   - Reference related issues
   - Include screenshots for UI changes
   - Ensure CI checks pass

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How has this been tested?

## Screenshots
(if applicable)

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests added/updated
- [ ] All tests pass
```

## Code Style

### Swift Style Guide

Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and these additional rules:

**Naming:**
- Use clear, descriptive names
- Prefer verbose over ambiguous names
- Use camelCase for variables and functions
- Use PascalCase for types and protocols

**Structure:**
- Keep functions focused and small (<50 lines ideally)
- Extract complex logic into separate functions
- Use meaningful parameter labels
- Group related functionality

**Comments:**
- Document public APIs with DocC comments
- Add comments for complex algorithms
- Explain "why" not "what"
- Keep comments up-to-date

**SwiftUI Best Practices:**
- Extract view components when view body exceeds 10 lines
- Use ViewModifiers for reusable styling
- Prefer @Observable over ObservableObject (iOS 17+)
- Use proper state management patterns

### Example

```swift
/// Scans a directory for files and subdirectories.
/// 
/// This function performs a deep scan of the specified directory,
/// returning file metadata including size, modification date, and permissions.
///
/// - Parameter path: The directory path to scan
/// - Returns: Array of file entries with metadata
/// - Throws: `FileSystemError` if directory cannot be accessed
func scanDirectory(at path: URL) async throws -> [FileEntry] {
    // Implementation
}
```

## Testing

### Running Tests

```bash
# Run all tests
xcodebuild test \
  -project MiMiNavigator.xcodeproj \
  -scheme MiMiNavigator \
  -destination 'platform=macOS'

# Run specific test
xcodebuild test \
  -project MiMiNavigator.xcodeproj \
  -scheme MiMiNavigator \
  -destination 'platform=macOS' \
  -only-testing:MiMiNavigatorTests/FileManagerTests
```

### Writing Tests

- Write tests for new features
- Update tests when modifying existing code
- Follow Arrange-Act-Assert pattern
- Use descriptive test names
- Mock external dependencies

Example:
```swift
func testFileScanning_whenDirectoryExists_returnsFiles() async throws {
    // Arrange
    let testPath = createTestDirectory()
    let scanner = FileScanner()
    
    // Act
    let files = try await scanner.scan(path: testPath)
    
    // Assert
    XCTAssertFalse(files.isEmpty)
    XCTAssertTrue(files.allSatisfy { $0.path.hasPrefix(testPath) })
}
```

## Documentation

### Code Documentation

Use DocC-style comments for public APIs:

```swift
/// A brief description of the function.
///
/// A more detailed explanation that may span
/// multiple lines and include markdown:
/// - Important note
/// - Another note
///
/// ## Example Usage
/// ```swift
/// let result = try await myFunction(parameter: value)
/// ```
///
/// - Parameters:
///   - parameter: Description of parameter
/// - Returns: Description of return value
/// - Throws: Description of errors that can be thrown
func myFunction(parameter: String) async throws -> Result { }
```

### Markdown Files

When updating documentation:
- Use clear headings
- Include code examples
- Add links to relevant sections
- Keep language simple and clear
- Update table of contents

## Getting Help

- **Issues**: Browse [existing issues](https://github.com/senatov/MiMiNavigator/issues)
- **Discussions**: Start a [discussion](https://github.com/senatov/MiMiNavigator/discussions)
- **Email**: Contact the maintainer

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Give constructive feedback
- Focus on the best outcome for the project

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to MiMiNavigator! 🎉

