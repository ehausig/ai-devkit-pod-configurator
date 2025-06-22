#### Python (Miniconda)

**Environment Setup for Projects**:
```bash
# Create project environment
conda create -n PROJECT_NAME python=3.11 -y
echo "$(date -Iseconds) [INFO] Created conda environment: PROJECT_NAME" >> ~/workspace/JOURNAL.md

# Activate environment (ALWAYS use eval first)
eval "$(conda shell.bash hook)"
conda activate PROJECT_NAME
echo "$(date -Iseconds) [INFO] Activated conda environment" >> ~/workspace/JOURNAL.md
```

**Project Dependencies**:
```bash
# Create requirements.txt FIRST
cat > requirements.txt << 'EOF'
# Core dependencies
textual>=0.47.0      # For TUI apps
pytest>=8.0.0
pytest-asyncio>=0.23.0
pytest-cov>=4.1.0
EOF

# Install from requirements
pip install -r requirements.txt
```

**Testing with Conda**:
```bash
# Always activate environment first
eval "$(conda shell.bash hook)" && conda activate PROJECT_NAME

# Run pytest
pytest tests/ -v --cov=src

# For TUI apps also use:
pip install textual-dev
textual run --dev src/app.py
```

**Common Activation Fix**:
```bash
eval "$(conda shell.bash hook)"
conda activate myenv
```

**Best Practices**:
- Export env: `conda env export > environment.yml`
- Create from file: `conda env create -f environment.yml`
- Clean cache: `conda clean -a`
- List envs: `conda env list`

**TUI Development Stack**:
```bash
pip install textual textual-dev pytest pytest-asyncio
```

## TUI Testing with Microsoft TUI Test

**IMPORTANT**: Conda environments can cause issues with TUI Test due to symlinks. Use one of these approaches:

### Option 1: External Conda Environment (Recommended)
```bash
# Create conda env outside project directory
conda create -n myapp python=3.11 -y
conda activate myapp
cd ~/workspace/myproject
pip install -r requirements.txt

# Run TUI tests normally
npx @microsoft/tui-test
```

### Option 2: Use Conda's Python Directly
```typescript
// In your test file, reference conda's python directly
test.use({ 
    program: { 
        file: "/opt/conda/envs/myapp/bin/python", 
        args: ["src/main.py"] 
    } 
});
```

### Option 3: Create Wrapper Script
```bash
# Create run-app.sh
cat > run-app.sh << 'EOF'
#!/bin/bash
source /opt/conda/etc/profile.d/conda.sh
conda activate myapp
python src/main.py "$@"
EOF
chmod +x run-app.sh

# Test the wrapper
test.use({ program: { file: "./run-app.sh" } });
```

### Example TUI Test for Python App
```typescript
import { test, expect } from "@microsoft/tui-test";

test.describe("Python TUI Application", () => {
    test.beforeEach(async ({ terminal }) => {
        // Use external conda env approach
        test.use({ 
            program: { 
                file: "python", 
                args: ["src/main.py"] 
            },
            cwd: "/home/devuser/workspace/myproject"
        });
    });

    test("app starts successfully", async ({ terminal }) => {
        await expect(terminal.getByText("Welcome")).toBeVisible();
    });

    test("navigation works", async ({ terminal }) => {
        await expect(terminal.getByText("Main Menu")).toBeVisible();
        terminal.sendNavigationKey("down");
        terminal.sendNavigationKey("enter");
        await expect(terminal.getByText("Settings")).toBeVisible();
    });
});
```

**Best Practices for TUI Testing**:
- Keep conda environments outside the project directory
- Use absolute paths to Python interpreters when needed
- Create wrapper scripts for complex activation scenarios
- Test both the development and production environments
