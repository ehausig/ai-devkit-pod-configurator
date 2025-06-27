#### Python (Miniconda)

**Environment Setup**
```bash
# Create and activate environment
conda create -n myproject python=3.11 -y
eval "$(conda shell.bash hook)"
conda activate myproject

# Common activation fix if needed
eval "$(conda shell.bash hook)" && conda activate myproject
```

**Project Init**
```bash
# Create project structure
mkdir -p src tests docs
touch README.md requirements.txt .gitignore

# Create requirements.txt
cat > requirements.txt << 'EOF'
textual>=0.47.0      # TUI framework
pytest>=8.0.0
pytest-asyncio>=0.23.0
pytest-cov>=4.1.0
ruff>=0.1.0
black>=23.0.0
EOF
```

**Dependencies**
```bash
# Install from requirements
pip install -r requirements.txt

# Add new dependency
pip install package_name
pip freeze > requirements.txt

# Export/import environment
conda env export > environment.yml
conda env create -f environment.yml
```

**Format & Lint**
```bash
# Format with black
black src/ tests/

# Lint with ruff
ruff check src/ tests/
ruff check --fix src/ tests/  # Auto-fix
```

**Testing**

*Unit Tests*
```bash
# Run unit tests
pytest tests/unit/ -v

# With coverage
pytest tests/unit/ -v --cov=src --cov-report=term-missing

# Run specific test
pytest tests/unit/test_module.py::test_function -v

# Example structure
# tests/unit/test_calculator.py
def test_add():
    assert add(2, 3) == 5

def test_add_negative():
    assert add(-1, 1) == 0
```

*Integration Tests*
```bash
# Database/API tests
pytest tests/integration/ -v

# Example: Testing with database
# tests/integration/test_user_service.py
import pytest
from sqlalchemy import create_engine

@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    # Setup tables
    yield engine
    # Teardown

def test_user_creation(db):
    user_service = UserService(db)
    user = user_service.create("alice@example.com")
    assert user.id is not None
```

*User Simulation Tests*
```bash
# TUI testing with Microsoft TUI Test
npx @microsoft/tui-test tests/e2e/

# Web UI testing with Playwright
pytest tests/e2e/ --headed

# Example: Playwright test
# tests/e2e/test_login_flow.py
from playwright.sync_api import Page

def test_login_flow(page: Page):
    page.goto("http://localhost:8000")
    page.fill("[name='email']", "user@example.com")
    page.fill("[name='password']", "password")
    page.click("button[type='submit']")
    assert page.url == "http://localhost:8000/dashboard"
```

**Build**
```bash
# Python doesn't require compilation
# For distribution:
pip install build
python -m build  # Creates dist/ with .whl and .tar.gz
```

**Run**
```bash
# Run module
python -m src.main

# Run script
python src/app.py

# For TUI development
textual run --dev src/app.py
```

**Security Scanning**
```bash
# Run security checks locally
pip install safety bandit

# Check for known vulnerabilities
safety check

# Static security analysis
bandit -r src/

# Check for outdated packages
pip list --outdated
```

**Pre-commit Hooks (Local)**
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.0
    hooks:
      - id: ruff
  
  - repo: https://github.com/psf/black
    rev: 23.0.0
    hooks:
      - id: black
  
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.7.0
    hooks:
      - id: mypy
        additional_dependencies: [types-all]

# Install and use locally:
pip install pre-commit
pre-commit install
pre-commit run --all-files  # Run manually
```

**TUI Testing Notes**
- Keep conda environments outside project directory to avoid symlink issues with TUI Test
- Use `conda create -n myapp -p ~/envs/myapp python=3.11` for external environments
- Reference conda's python directly in tests: `/opt/conda/envs/myapp/bin/python`
