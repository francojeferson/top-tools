# VSCode Extensions

> _Current setup: Windows 11, Git, Node.js, Python, Go, VSCodium, telemetry off_

---

## Quick Reference

### Performance Impact Guide

- 🟢 Low: <50MB memory, minimal CPU usage
- 🟡 Medium: 50-100MB memory, moderate CPU usage
- 🔴 High: >100MB memory, significant CPU usage

### Status Definitions

- **Active**: Currently recommended and maintained
- **Standby**: Recommended but not currently installed
- **Replaced**: Superseded by native features
- **Deprecated**: No longer available/supported

---

## Summary Table

| Extension Name                   | Status     | Performance | Notes/Replacement                                       |
| -------------------------------- | ---------- | ----------- | ------------------------------------------------------- |
| autoDocstring                    | Active     | 🟢 Low      | Generating docstrings for Python                        |
| Black Formatter                  | Active     | 🟢 Low      | Python formatting                                       |
| Bookmarks                        | Active     | 🟢 Low      | Code navigation                                         |
| Cline                            | Active     | 🟡 Medium   | AI code assistant                                       |
| ES7+ Snippets                    | Active     | 🟢 Low      | JavaScript and React/Redux snippets                     |
| ESLint                           | Active     | 🟢 Low      | JavaScript and TypeScript linting and code quality tool |
| isort                            | Active     | 🟢 Low      | Python import sorting                                   |
| JavaScript ES6 snippets          | Active     | 🟢 Low      | JavaScript code snippets                                |
| markdownlint                     | Active     | 🟢 Low      | Linting for Markdown files to ensure style consistency  |
| Markdown Preview GitHub          | Active     | 🟢 Low      | GitHub-flavored Markdown preview                        |
| Markdown Preview Mermaid Support | Active     | 🟢 Low      | Mermaid diagram support                                 |
| Prettier                         | Active     | 🟢 Low      | Code formatter                                          |
| Python                           | Active     | 🟡 Medium   | Python development environment                          |
| Python Debugger                  | Active     | 🟡 Medium   | Python debugging support                                |
| Python Indent                    | Active     | 🟢 Low      | Python indentation                                      |
| SVG                              | Active     | 🟢 Low      | SVG editing and visualization                           |
| Tailwind CSS IntelliSense        | Active     | 🟡 Medium   | Tailwind CSS tooling                                    |
| WakaTime                         | Active     | 🟢 Low      | Time tracking for developers                            |
| AREPL                            | Standby    | 🟡 Medium   | Real-time Python code evaluation                        |
| Django                           | Standby    | 🟡 Medium   | Django framework development                            |
| Editor Config                    | Standby    | 🟢 Low      | Maintain consistent coding styles                       |
| Postman                          | Standby    | 🟡 Medium   | API development and testing                             |
| Python Environment Manager       | Standby    | 🟡 Medium   | Managing Python environments                            |
| Auto Close Tag                   | Replaced   | 🟢 Low      | Native settings                                         |
| Auto Commit Message              | Replaced   | 🟢 Low      | Keyboard shortcuts                                      |
| Auto Rename Tag                  | Replaced   | 🟢 Low      | Native settings                                         |
| Cody                             | Replaced   | 🔴 High     | Cline                                                   |
| Color Highlight                  | Replaced   | 🟢 Low      | Native settings                                         |
| Continue                         | Replaced   | 🔴 High     | Cline                                                   |
| Material Icon Theme              | Replaced   | 🟢 Low      | Native settings                                         |
| GitHub Copilot                   | Deprecated | 🟢 Low      | Not available on VSCodium                               |
| IntelliCode                      | Deprecated | 🔴 High     | Not available on VSCodium                               |
| Minify                           | Deprecated | 🟡 Medium   | Not available on VSCodium                               |
| Smart Column Indenter            | Deprecated | 🟢 Low      | Not available on VSCodium                               |

---

## Migration Guides

### Auto Close Tag to Native

```json
{
  "editor.autoClosingBrackets": "always",
  "editor.autoClosingQuotes": "always",
  "editor.autoClosingDelete": "always",
  "html.autoClosingTags": true
}
```

**Benefits**:

- Reduced extension overhead
- Faster performance
- Built-in maintenance

### Auto Rename Tag to Native

```json
{
  "editor.linkedEditing": true
}
```

**Benefits**:

- Better performance
- Native integration
- Reliable updates

### Color Highlight to Native

```json
{
  "editor.colorDecorators": true
}
```

**Benefits**:

- Seamless integration
- Reduced memory usage
- Consistent behavior

### Material Icon Theme to Native

```json
{
  "workbench.iconTheme": "vs-minimal"
}
```

**Benefits**:

- Faster loading
- System integration
- Regular updates

### Auto Commit Message to Custom

```txt
Generate a commit message using Conventional Commits:

1. Type: feat, fix, docs, style, refactor, perf, test, build, ci, chore
2. Format: <type>[scope]: <description>
3. First line: max 50 characters
4. Body: wrap at 72 characters

Example:
feat(user-auth): add password reset functionality
Implement reset API, email template, and form component
Closes #123
```

---

## Troubleshooting Guide

### General Issues

1. Extension Not Loading

   - Clear VSCode cache
   - Reload window
   - Reinstall extension
   - Check compatibility

2. Performance Problems

   - Disable unused extensions
   - Monitor memory usage
   - Update extensions
   - Clear workspace cache

3. Configuration Conflicts

   - Check settings.json
   - Review workspace settings
   - Disable conflicting extensions
   - Reset to defaults

### Extension-Specific Solutions

1. Python Tools

   - Verify Python installation
   - Check interpreter settings
   - Update language server
   - Validate workspace trust

2. JavaScript/TypeScript Tools

   - Clear TypeScript server
   - Update npm packages
   - Check jsconfig.json
   - Verify node version

3. Formatting Tools

   - Check formatter config
   - Validate file associations
   - Review workspace settings
   - Update language servers

---

## Best Practices

1. Extension Management

   - Regular cleanup
   - Performance monitoring
   - Update scheduling
   - Conflict resolution

2. Configuration

   - Use workspace settings
   - Document overrides
   - Version control settings
   - Regular backups

3. Performance

   - Minimal active extensions
   - Regular maintenance
   - Profile monitoring
   - Cache management

---

### EditorConfig and Prettier Usage

When using an `.editorconfig` file, it is essential to also use a `.prettierrc` file together to avoid conflicts in
formatting. The `.prettierrc` file should follow this structure:

```json
{
  "editorconfig": true,
  "trailingComma": "all",
  "printWidth": 120,
  "singleQuote": true,
  "semi": false
}
```

**Note:** Once a local configuration file (e.g., `.prettierrc` or `.editorconfig`) is detected, VS Code's own formatting
settings will not be applied.

---

## ESLint Extension Setup and Configuration

To include ESLint in your project, follow these installation and configuration instructions:

1\. Add the following dev-dependencies to your `package.json`:

```json
"eslint": "^8.36.0",
"@typescript-eslint/eslint-plugin": "^5.56.0",
"eslint-config-prettier": "^8.8.0",
"eslint-config-standard-with-typescript": "^34.0.1",
"eslint-plugin-import": "^2.27.5",
"eslint-plugin-n": "^15.6.1",
"eslint-plugin-prettier": "^4.2.1",
"eslint-plugin-promise": "^6.1.1",
"eslint-plugin-react": "^7.32.2",
"prettier": "^2.8.7"
```

2\. This setup works only for the ESLint legacy configuration.

3\. Create a `.eslintrc.js` file in the root of your project with the following content:

```js
module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  env: {
    browser: true,
    es2021: true,
    node: true
  },
  plugins: ['react', 'prettier', '@typescript-eslint'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react/recommended',
    'plugin:prettier/recommended'
  ],
  overrides: [],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  settings: {
    react: {
      version: 'detect'
    }
  },
  ignorePatterns: ['node_modules/', '_explicacoes/'],
  rules: {
    '@typescript-eslint/no-unused-vars': 'off'
  }
}
```

4\. The `rules` section is fully customizable to fit your project's needs.

5\. As a good practice, include the following scripts in your `package.json`:

```json
"lint": "eslint ./**/*.{js,jsx,ts,tsx}",
"lint:fix": "npm run lint -- --fix",
```

---

## Additional Resources

- [VSCode Documentation](https://code.visualstudio.com/docs)
- [Extension API](https://code.visualstudio.com/api)
- [Performance Issues](https://code.visualstudio.com/docs/supporting/troubleshoot-performance)
- [Settings Reference](https://code.visualstudio.com/docs/getstarted/settings)
