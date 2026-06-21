```markdown
# monadic-chat Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches the core development patterns and workflows found in the `monadic-chat` Ruby codebase. It covers file organization, code style, import/export conventions, testing practices, and common maintenance workflows such as updating README badges. This guide is designed to help contributors quickly align with the project's established practices.

## Coding Conventions

### File Naming
- Use **snake_case** for all file names.
  - Example: `chat_handler.rb`, `user_session.rb`

### Import Style
- Use **relative imports** within the codebase.
  - Example:
    ```ruby
    require_relative './chat_handler'
    ```

### Export Style
- Use **named exports** (explicitly defining what is exported from a file).
  - Example:
    ```ruby
    module ChatHandler
      # ...module code...
    end
    ```

### Commit Messages
- Freeform style, no strict prefixes.
- Average commit message length: ~46 characters.
- Example:
  ```
  Fix user session bug in chat handler
  ```

## Workflows

### Update README Badges
**Trigger:** When you need to update the status, release, or cache badges displayed in `README.md`.
**Command:** `/update-readme-badge`

1. Open `README.md` in your editor.
2. Adjust existing badge parameters or add new badges as needed.
   - For example, to add a new release badge:
     ```markdown
     ![Release](https://img.shields.io/github/v/release/yourorg/monadic-chat)
     ```
3. Save your changes.
4. Commit the changes with a message referencing badges or release display.
   - Example commit message:
     ```
     Update README badges for latest release
     ```
5. Push your changes and open a pull request if required.

## Testing Patterns

- **Framework:** Jest (JavaScript testing framework)
- **Test File Pattern:** Files end with `.test.js`
  - Example: `chat_handler.test.js`
- **Test Example:**
  ```javascript
  // chat_handler.test.js
  const { handleChat } = require('./chat_handler');

  test('should process chat message', () => {
    expect(handleChat('hello')).toBe('processed: hello');
  });
  ```

## Commands

| Command              | Purpose                                              |
|----------------------|------------------------------------------------------|
| /update-readme-badge | Update or add badges in the README.md file           |

```