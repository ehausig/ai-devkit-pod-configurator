#### Microsoft TUI Test

**Quick Start**:
```bash
# Initialize TUI Test in your project
tui-test-init

# Copy example test
tui-test-example

# Run tests
npx @microsoft/tui-test
```

**Writing Tests**:
```typescript
import { test, expect } from "@microsoft/tui-test";

test("basic terminal test", async ({ terminal }) => {
    terminal.write("echo 'Hello World'");
    terminal.submit();
    
    await expect(terminal.getByText("Hello World")).toBeVisible();
});
```

**Testing TUI Applications**:
```typescript
test("test CLI app", async ({ terminal }) => {
    test.use({ program: { file: "python", args: ["app.py"] } });
    
    // Wait for prompt
    await expect(terminal.getByText(">")).toBeVisible();
    
    // Navigate menu
    terminal.sendNavigationKey("down");
    terminal.sendNavigationKey("enter");
    
    // Assert result
    await expect(terminal.getByText("Selected")).toBeVisible();
});
```

**Configuration** (`tui-test.config.ts`):
- Set retries, timeout, parallel execution
- Configure trace capture for debugging
- Already configured with sensible defaults

**Debugging**:
- View traces: `tui-test-trace`
- Traces saved in `tui-traces/` directory

**Best Practices**:
- Use `waitForRender()` after commands
- Take snapshots for visual regression
- Test keyboard navigation thoroughly
