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
