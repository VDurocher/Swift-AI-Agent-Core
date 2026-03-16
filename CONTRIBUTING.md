# Contributing to Swift AI Agent Core

First off, thank you for considering contributing to Swift AI Agent Core! It's people like you that make this package better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by respect, professionalism, and collaboration. By participating, you are expected to uphold this standard.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (code snippets, screenshots)
- **Describe the behavior you observed** and what you expected
- **Include your environment details** (iOS version, Xcode version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List any alternatives** you've considered

### Pull Requests

1. **Fork the repo** and create your branch from `main`
2. **Follow the existing code style** (see below)
3. **Add tests** for any new functionality
4. **Update documentation** as needed
5. **Ensure all tests pass** with `swift test`
6. **Submit your pull request**

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/Swift-AI-Agent-Core.git
cd Swift-AI-Agent-Core

# Build the package
swift build

# Run tests
swift test
```

## Coding Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use Swift 6.0 features (async/await, actors, structured concurrency)
- All public types must be documented with DocC comments
- Use meaningful variable and function names
- Keep functions focused and small

### Example

```swift
/// Sends a message to the AI agent and returns the response
///
/// - Parameter message: The message to send
/// - Returns: The AI's response as a string
/// - Throws: `AIError` if the request fails
public func send(message: String) async throws -> String {
    // Implementation
}
```

### Concurrency

- Use `async/await` for asynchronous operations
- Mark types as `Sendable` where appropriate
- Use `actor` for mutable shared state
- Avoid completion handlers and callbacks

### Error Handling

- Use typed errors (`AIError`) not generic `Error`
- Provide descriptive error messages
- Include recovery suggestions where appropriate

### Testing

- Write unit tests for all new functionality
- Aim for high code coverage
- Use descriptive test names: `testFunctionName_WhenCondition_ThenExpectedResult`
- Include edge cases and error scenarios

```swift
func testSendMessage_WithValidInput_ReturnsResponse() async throws {
    // Given
    let agent = try MockAIAgent()
    let message = "Hello"

    // When
    let response = try await agent.send(message: message)

    // Then
    XCTAssertFalse(response.isEmpty)
}
```

## Documentation

- Update README.md if you change functionality
- Add DocC comments to all public APIs
- Include code examples in documentation
- Update Examples/ if you add new features

## Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit first line to 72 characters
- Reference issues and pull requests when relevant

### Examples

```
Add streaming support for Claude API

- Implement AsyncThrowingStream for Claude responses
- Add unit tests for streaming functionality
- Update README with streaming examples

Fixes #123
```

## Release Process

Maintainers will handle releases. Version numbers follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward-compatible)
- **PATCH**: Bug fixes (backward-compatible)

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

## Recognition

Contributors will be recognized in the project. Thank you for your contributions!

---

**Happy coding! 🚀**
