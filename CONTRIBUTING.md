# Contributing to MiMiNavigator

Thank you for your interest in contributing to MiMiNavigator!

## Development Setup

1. **Requirements**
   - macOS 15.4+
   - Xcode 16+ (with Swift 6.2 support)
   - Git

2. **Getting Started**
   ```bash
   git clone https://github.com/senatov/MiMiNavigator.git
   cd MiMiNavigator
   open MiMiNavigator.xcodeproj
   ```

3. **Build & Run**
   - Use Xcode to build and run the project
   - Or use the provided script: `./Scripts/build_debug.zsh`

## Code Quality

We use several tools to maintain code quality:

- **SwiftLint**: Ensures code style consistency
  ```bash
  swiftlint
  ```

- **Swift-format**: Code formatting
  ```bash
  swift-format --recursive Gui/Sources
  ```

- **Periphery**: Detects unused code
  ```bash
  periphery scan --config .periphery.yml
  ```

## Commit Guidelines

Please follow these conventions:

- Write commit messages in English
- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters

### Commit Message Format

```
type: subject

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat: add three-panel layout support

fix: resolve panel divider positioning issue

docs: update README with installation instructions
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run code quality checks (SwiftLint, Swift-format)
5. Commit your changes following the commit guidelines
6. Push to your fork
7. Open a Pull Request

## Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small
- Write unit tests for new features

## Questions?

Feel free to open an issue for any questions or concerns.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
