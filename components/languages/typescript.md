#### TypeScript

**Setup**: `tsc --init` (creates tsconfig.json)

**Commands**:
- Compile: `tsc` or `tsc file.ts`
- Watch: `tsc --watch`
- Run directly: `ts-node script.ts`
- Type check only: `tsc --noEmit`

**Testing with Jest**:
```bash
npm install -D jest @types/jest ts-jest
npx ts-jest config:init
```

**Development Scripts**:
```json
{
  "scripts": {
    "dev": "ts-node-dev --respawn src/server.ts",
    "build": "tsc",
    "test": "jest --watch"
  }
}
```

**Common Issues**:
- Module resolution: Set `"moduleResolution": "node"`
- Missing types: `npm i -D @types/package-name`

**tsconfig.json**: Enable `"strict": true` for better type safety
