# Contributing to ExTholosPq

Thank you for considering contributing to ExTholosPq! We welcome contributions from the community.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/ex_tholos-pq.git`
3. Create a new branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `mix test`
6. Commit your changes: `git commit -am 'Add some feature'`
7. Push to the branch: `git push origin feature/your-feature-name`
8. Create a Pull Request

## Development Setup

### Prerequisites

- Elixir 1.14 or later
- Erlang/OTP 24 or later
- Rust toolchain (stable)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/ex_tholos-pq.git
cd ex_tholos-pq

# Install dependencies
make deps

# Compile the project
make compile

# Run tests
make test
```

## Code Style

### Elixir

- Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Run `mix format` before committing
- Ensure all code passes `mix credo --strict`

### Rust

- Follow standard Rust conventions
- Run `cargo fmt` before committing
- Ensure code passes `cargo clippy` with no warnings

## Testing

- Write tests for all new functionality
- Ensure all tests pass before submitting a PR
- Aim for high test coverage
- Include both positive and negative test cases

```bash
# Run Elixir tests
mix test

# Run with coverage
mix test --cover
```

## Documentation

- Document all public functions with `@doc` annotations
- Include examples in documentation
- Update the README.md if adding new features
- Add entries to CHANGELOG.md for notable changes

## Pull Request Process

1. Update the README.md with details of changes if applicable
2. Update the CHANGELOG.md with a note describing your changes
3. Ensure all tests pass and code is formatted
4. The PR will be merged once you have the sign-off of a maintainer

## Code of Conduct

### Our Pledge

We are committed to providing a friendly, safe, and welcoming environment for all contributors.

### Our Standards

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

### Unacceptable Behavior

- Trolling, insulting/derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate

## Questions?

Feel free to open an issue for:
- Questions about the codebase
- Suggestions for improvements
- Bug reports
- Feature requests

Thank you for contributing!



