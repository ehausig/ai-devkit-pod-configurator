#### Microsoft TUI Test

**Quick Start**:
```bash
# Install in project
npm install -D @microsoft/tui-test

# Create config file (or use alias)
tui-test-init  # Creates tui-test.config.ts

# Create example test
tui-test-example  # Creates example.test.ts

# Run tests
npx @microsoft/tui-test
```

**Writing Tests**:
```typescript
import { test, expect } from "@microsoft/tui-test";

// Basic test
test("CLI output test", async ({ terminal }) => {
    terminal.write("echo 'Hello World'");
    terminal.submit();
    await expect(terminal.getByText("Hello World")).toBeVisible();
});

// Test with specific program
test.use({ program: { file: "python", args: ["app.py"] } });
test("app startup", async ({ terminal }) => {
    await expect(terminal.getByText("Ready")).toBeVisible();
});
```

**Navigation & Interaction**:
```typescript
// Keyboard navigation
terminal.sendNavigationKey("down");   // Arrow down
terminal.sendNavigationKey("up");     // Arrow up
terminal.sendNavigationKey("enter");  // Enter key
terminal.sendNavigationKey("tab");    // Tab key

// Send special keys
terminal.sendKey("ctrl+c");  // Interrupt
terminal.sendKey("ctrl+d");  // EOF
terminal.sendKey("escape");  // ESC

// Wait for render
await terminal.waitForRender();
```

**Assertions**:
```typescript
// Text matching
await expect(terminal.getByText("exact text")).toBeVisible();
await expect(terminal.getByText(/regex pattern/)).toBeVisible();
await expect(terminal.getByText("text", { full: true })).toBeVisible();

// Terminal snapshots
await expect(terminal).toMatchSnapshot();
await expect(terminal).toMatchSnapshot("custom-name");
```

**Configuration** (`tui-test.config.ts`):
```typescript
import { defineConfig } from "@microsoft/tui-test";

export default defineConfig({
    retries: 3,              // Retry flaky tests
    trace: true,             // Enable traces
    timeout: 30000,          // 30s timeout
    parallel: true,          // Run in parallel
    workers: 4,              // Parallel workers
    shell: "bash",           // Default shell
    outputDir: "tui-traces"  // Trace directory
});
```

**Shell Support**:
- `bash`, `zsh`, `fish`, `xonsh`
- `powershell`, `cmd` (Windows)
- `git-bash` (Git for Windows)

**Debugging**:
```bash
# Run with traces
npx @microsoft/tui-test --trace

# View trace file
npx @microsoft/tui-test show-trace tui-traces/test-failed.zip

# Run specific test
npx @microsoft/tui-test test-file.ts -g "test name"
```

**TUI Testing Pattern**:
```typescript
test("TUI navigation test", async ({ terminal }) => {
    // Start TUI app
    test.use({ program: { file: "npm", args: ["start"] } });
    
    // Wait for menu
    await expect(terminal.getByText("Main Menu")).toBeVisible();
    
    // Navigate menu
    terminal.sendNavigationKey("down");
    terminal.sendNavigationKey("down");
    terminal.sendNavigationKey("enter");
    
    // Verify navigation
    await expect(terminal.getByText("Settings")).toBeVisible();
    
    // Take snapshot
    await expect(terminal).toMatchSnapshot("settings-screen");
});
```

**Best Practices**:
- Use `waitForRender()` after commands
- Enable traces for CI debugging
- Use snapshots for visual regression
- Test with multiple shells
- Set appropriate timeouts
- Use regex for dynamic content

**Common Issues**:
- **Timing**: Add `waitForRender()` between actions
- **Flaky tests**: Increase retries in config
- **Shell differences**: Test on target shells
- **Escape sequences**: Use regex patterns
