#### Python 3.10

**Virtual Environments** (always use for projects):
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate
```

**Testing**:
```python
# pytest (recommended)
pip install pytest pytest-cov
pytest -v --cov=mypackage

# unittest (built-in)
python -m unittest discover
```

**Development Tools**:
- Format: `pip install black && black .`
- Lint: `pip install ruff && ruff check .`
- Type check: `pip install mypy && mypy .`
- Debug: `python -m pdb script.py`

**Common Commands**:
- HTTP server: `python -m http.server 8000`
- Install to user: `pip install --user package`

## TUI Testing with Microsoft TUI Test

**IMPORTANT**: Python venv creates symlinks that conflict with TUI Test. Use these approaches:

### Option 1: External Virtual Environment (Recommended)
```bash
# Create venv outside project directory
python -m venv ~/venvs/myproject
source ~/venvs/myproject/bin/activate
cd ~/workspace/myproject
pip install -r requirements.txt

# Run TUI tests without venv in project
npx @microsoft/tui-test
```

### Option 2: Delete venv Before Testing
```bash
# Save current state
pip freeze > requirements.txt

# Remove venv for testing
deactivate
rm -rf .venv

# Run tests
npx @microsoft/tui-test

# Restore venv after testing
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Option 3: Use System Python in Tests
```typescript
// Reference system python with project in PYTHONPATH
test.use({ 
    program: { 
        file: "/usr/bin/python3", 
        args: ["src/main.py"] 
    },
    env: {
        PYTHONPATH: "/home/devuser/workspace/myproject"
    }
});
```

### Example TUI Test Configuration
```typescript
import { test, expect } from "@microsoft/tui-test";

test.describe("Python TUI App Tests", () => {
    test("application starts", async ({ terminal }) => {
        // Using external venv approach
        test.use({ 
            program: { 
                file: "/home/devuser/venvs/myproject/bin/python", 
                args: ["src/main.py"] 
            },
            cwd: "/home/devuser/workspace/myproject"
        });
        
        await expect(terminal.getByText("App Started")).toBeVisible();
    });
});
```

**Helper Script for Testing**:
```bash
# Create test-wrapper.sh
#!/bin/bash
export PYTHONPATH=/home/devuser/workspace/myproject
/usr/bin/python3 -m src.main "$@"
```

**Best Practices**:
- Keep virtual environments outside project when using TUI Test
- Use `~/venvs/PROJECT_NAME` convention
- Document the venv location in README
- Consider using make targets for test workflows
