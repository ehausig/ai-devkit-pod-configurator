#### Python 3.11

**Environment Setup**
```bash
# Create virtual environment
python3.11 -m venv .venv
source .venv/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel
```

**Project Init**
```bash
# Same structure as Python 3.10
mkdir -p src tests docs
touch README.md requirements.txt .gitignore pyproject.toml

# Modern pyproject.toml
cat > pyproject.toml << 'EOF'
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[project]
name = "myproject"
version = "0.1.0"
requires-python = ">=3.11"
EOF
```

**Dependencies**
```bash
# Core dependencies for modern Python
cat > requirements.txt << 'EOF'
# Async web
fastapi>=0.104.0
uvicorn[standard]>=0.24.0

# TUI
textual>=0.47.0

# Testing
pytest>=8.0.0
pytest-asyncio>=0.23.0
pytest-cov>=4.1.0

# Dev tools
black>=23.0.0
ruff>=0.1.0
mypy>=1.7.0
EOF

pip install -r requirements.txt
```

**Format & Lint**
```bash
# Black for formatting
black src/ tests/

# Ruff for fast linting
ruff check src/ tests/
ruff check --fix src/ tests/

# Type checking
mypy src/ --python-version 3.11
```

**Testing**
```bash
# Standard pytest
pytest -v

# With coverage
pytest -v --cov=src --cov-report=html

# Async tests
@pytest.mark.asyncio
async def test_async_function():
    result = await async_function()
    assert result == expected
```

**Build**
```bash
# Build with modern tools
pip install build
python -m build

# Creates wheel and sdist
# dist/*.whl
# dist/*.tar.gz
```

**Run**
```bash
# FastAPI app
uvicorn src.main:app --reload

# Textual TUI app
textual run --dev src/app.py

# Module execution
python -m src.main

# With optimizations
python -O -m src.main
```

**TUI Testing Notes**
- Same venv/symlink issues as Python 3.10
- Use external venv: `python3.11 -m venv ~/venvs/myproject`
- Exception groups provide better error context in tests
