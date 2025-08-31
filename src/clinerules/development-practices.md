---
description:
  Comprehensive guide for development practices including version control, testing, and documentation standards.
author: Cline
version: 1.0
tags: ['version-control', 'testing', 'documentation', 'best-practices']
globs: ['*']
---

# Development Practices

## Version Control

### Commit Message Format

All commit messages MUST follow the [Conventional Commits](https://www.conventionalcommits.org/) standard to maintain a
clear and consistent git history.

#### Format

```ini
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Rules

1. First line MUST be under 50 characters
2. Description MUST be in imperative mood (e.g., "add" not "adds")
3. Body lines MUST be wrapped at 72 characters
4. Type MUST be one of:
   - feat: New feature
   - fix: Bug fix
   - docs: Documentation changes
   - style: Code style/formatting changes
   - refactor: Code changes that neither fix bugs nor add features
   - perf: Performance improvements
   - test: Adding or modifying tests
   - build: Build system or external dependency changes
   - ci: CI configuration changes
   - chore: Other changes that don't modify src or test files

#### Examples

```ini
feat(auth): add password reset functionality
Implement reset API, email template, and form component
Closes #123

fix(api): handle null response from user service
Previously the app would crash when the service returned null
Fixes #456

docs(readme): update installation instructions
Add section about environment variables and prerequisites

style(lint): apply prettier formatting to src files

refactor(core): extract validation logic to utils
Move shared validation code to a new utilities module for reuse

perf(queries): optimize user search algorithm
Replace O(n²) implementation with O(n log n) approach
Improves search time by 75% on large datasets

test(api): add integration tests for auth routes

build(deps): upgrade typescript to 4.9.5

ci(actions): add node 18 to test matrix

chore(git): update .gitignore patterns
```

#### Additional Guidelines

1. **Breaking Changes:**

   - Add BREAKING CHANGE: in the commit body
   - Or append ! after type: `feat!: remove support for X`

2. **Multiple Scopes:**

   - Use comma separation: `feat(api,auth): add OAuth support`

3. **References:**

   - Reference issues/PRs in footer: `Fixes #123, #456`
   - Or in description if simple: `fix(ui): center logo (#789)`

4. **Revert Commits:**
   - Start with `revert:` followed by original commit header
   - Body should contain: `This reverts commit <hash>`

## Testing

### Test-Driven Development (TDD)

1. **Write a failing test** that defines a new function or improvement.
2. **Write the minimal code** to make the test pass.
3. **Refactor** the new code to acceptable standards.

### Test Coverage

- Aim for high test coverage (ideally >80%) for production code.
- Include unit tests, integration tests, and end-to-end tests as appropriate.
- Mock external dependencies to ensure tests are isolated and fast.

### Test Organization

- Place test files alongside the source code they test (e.g., `src/utils/helpers.js` and `src/utils/helpers.test.js`).
- Use consistent naming conventions for test files (e.g., `*.test.js` or `*.spec.js`).
- Group related tests in suites that mirror your source code structure.

## Documentation

### Code Documentation

- Write clear, concise comments for complex logic, algorithms, and business rules.
- Document all public APIs with JSDoc or similar comment syntax.
- Keep documentation in sync with code changes.

### README Documentation

- Maintain a comprehensive README.md in project roots.
- Include setup instructions, usage examples, and contribution guidelines.
- Document project structure and key architectural decisions.

### API Documentation

- Generate API documentation from code comments where possible.
- Keep API documentation up-to-date with changes.
- Include request/response examples for all endpoints.

## Code Quality

### Coding Standards

- Follow consistent naming conventions (camelCase, PascalCase, snake_case, etc.).
- Use a linter and formatter appropriate for your language/framework.
- Enforce a maximum line length (typically 80-120 characters).

### Code Reviews

- All significant code changes should be reviewed by peers.
- Use pull requests/merge requests for team collaboration.
- Provide constructive feedback focused on code quality, maintainability, and correctness.

### Technical Debt

- Regularly allocate time for refactoring and reducing technical debt.
- Track technical debt in your project management tool.
- Balance feature development with paying down technical debt.

## Security Best Practices

- Validate all external input to prevent injection attacks.
- Use parameterized queries for database access.
- Store secrets securely using environment variables or secret management systems.
- Regularly update dependencies to patch security vulnerabilities.
- Implement proper authentication and authorization controls.
- Follow the principle of least privilege for access controls.

## Performance Optimization

- Profile your application to identify bottlenecks.
- Use caching strategies appropriate for your use case.
- Optimize database queries and indexing.
- Implement lazy loading where appropriate.
- Monitor and set performance budgets for key metrics.

## Continuous Integration/Continuous Deployment (CI/CD)

- Automate build, test, and deployment processes.
- Maintain a clear deployment pipeline with appropriate stages.
- Use infrastructure as code for consistent environments.
- Implement automated rollbacks for failed deployments.
- Monitor application health in production.

## Accessibility (a11y)

- Follow WCAG guidelines for web applications.
- Ensure all UI elements are keyboard navigable.
- Provide ARIA labels for assistive technologies.
- Test your application with screen readers.
- Provide text alternatives for non-text content.
