#### Python 3.11

**Performance**: 10-60% faster than 3.10

**New Features**:
- Better error messages with exact locations
- Exception groups: `except* ExceptionGroup`
- Type improvements: `Self` type

**Testing**:
```python
# pytest with async
pip install pytest pytest-asyncio pytest-cov

@pytest.mark.asyncio
async def test_async():
    result = await async_function()
    assert result == expected
```

**TUI Stack**:
```bash
pip install textual textual-dev
pip install gql[aiohttp] aiohttp pydantic
```

**Development**:
- Format: `black .`
- Lint: `ruff check .`
- Type check: `mypy .`
- Debug: `python -m pdb`

## TUI Testing with Microsoft TUI Test

**IMPORTANT**: Like Python 3.10, venv creates symlinks that conflict with TUI Test. Use the same approaches:

### Option 1: External Virtual Environment (Recommended)
```bash
# Create venv outside project
python3.11 -m venv ~/venvs/myproject
source ~/venvs/myproject/bin/activate
cd ~/workspace/myproject
pip install -r requirements.txt

# TUI Test works without venv in project dir
npx @microsoft/tui-test
```

### Option 2: Docker-based Testing
```dockerfile
# Dockerfile.test
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/ src/
COPY tests/ tests/
CMD ["python", "src/main.py"]
```

```typescript
// Test against Docker container
test.use({ 
    program: { 
        file: "docker", 
        args: ["run", "-it", "myapp-test"] 
    } 
});
```

### Option 3: Project-specific Test Script
```bash
# Create tui-test-runner.sh
#!/bin/bash
# This script manages venv for TUI testing

if [ -d ".venv" ]; then
    echo "Backing up .venv..."
    mv .venv .venv.backup
fi

# Run TUI tests
npx @microsoft/tui-test "$@"
TEST_RESULT=$?

if [ -d ".venv.backup" ]; then
    echo "Restoring .venv..."
    mv .venv.backup .venv
fi

exit $TEST_RESULT
```

### Python 3.11 Specific Test Example
```typescript
import { test, expect } from "@microsoft/tui-test";

test.describe("Python 3.11 TUI Features", () => {
    test("exception groups display correctly", async ({ terminal }) => {
        test.use({ 
            program: { 
                file: "python3.11", 
                args: ["-m", "src.main"] 
            },
            cwd: "/home/devuser/workspace/myproject",
            env: {
                PYTHONPATH: "/home/devuser/workspace/myproject"
            }
        });
        
        // Test error handling with new exception groups
        terminal.sendKey("ctrl+e"); // Trigger error
        await expect(terminal.getByText("ExceptionGroup")).toBeVisible();
    });
});
```

**Recommended Workflow**:
1. Develop with venv in project (normal Python workflow)
2. Use external venv or system Python for TUI testing
3. Document the testing setup in your README
4. Consider GitHub Actions for CI where venv location doesn't matter
