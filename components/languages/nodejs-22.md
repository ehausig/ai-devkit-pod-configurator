#### Node.js 22.11.0 (Current)

**What's New in Node.js 22**:
- Native `.env` file support (experimental)
- WebSocket client built-in
- Improved performance and memory usage
- Enhanced test runner capabilities

**Quick Start**:
- Init project: `npm init -y`
- Install deps: `npm install express`
- Install dev: `npm install --save-dev jest`
- Run scripts: `npm run test`

**Native Test Runner** (Node.js 22+):
```javascript
// test.js
import { test } from 'node:test';
import assert from 'node:assert';

test('synchronous test', (t) => {
  assert.strictEqual(1 + 1, 2);
});
```
Run with: `node --test`

**Development Scripts**:
```json
{
  "scripts": {
    "dev": "node --watch server.js",
    "test": "node --test",
    "test:coverage": "node --test --experimental-test-coverage"
  }
}
```

**Best Practices**:
- Use `package-lock.json` for reproducible builds
- Check vulnerabilities: `npm audit`
- Use native features when possible

**Common**: REPL → `node`, Run file → `node app.js`

**NPM Global Packages**:
- Packages installed globally go to `~/.npm-global/`
- Already in PATH via `NPM_CONFIG_PREFIX`
