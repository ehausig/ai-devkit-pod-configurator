#### Node.js 20.18.0

**Quick Start**:
- Init project: `npm init -y`
- Install deps: `npm install express`
- Install dev: `npm install --save-dev jest`
- Run scripts: `npm run test`

**Testing**:
```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  }
}
```

**Development Scripts**:
```json
{
  "scripts": {
    "dev": "nodemon server.js",
    "lint": "eslint .",
    "format": "prettier --write ."
  }
}
```

**Best Practices**:
- Use `package-lock.json` for reproducible builds
- Check vulnerabilities: `npm audit`
- Test continuously: `npm run test:watch`

**Common**: REPL → `node`, Run file → `node app.js`

## TUI Testing with Node.js

Since TUI Test is pre-installed globally, you can test any Node.js TUI application:

```typescript
import { test, expect } from "@microsoft/tui-test";

test("Node.js CLI app", async ({ terminal }) => {
    test.use({ program: { file: "node", args: ["cli.js"] } });
    
    await expect(terminal.getByText("CLI Started")).toBeVisible();
    
    terminal.write("help");
    terminal.submit();
    
    await expect(terminal.getByText("Available commands")).toBeVisible();
});
```

**Testing Node.js TUI Apps**:
- Use `tui-test-init` to create config
- Test with `npx @microsoft/tui-test`
- No installation needed - already global
