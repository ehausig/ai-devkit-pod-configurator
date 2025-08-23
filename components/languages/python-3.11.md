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
```

Create pyproject.toml:
```toml
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[project]
name = "myproject"
version = "0.1.0"
requires-python = ">=3.11"
```

**Dependencies**
```bash
# Core dependencies for modern Python
```

Create requirements.txt:
```
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
```

```bash
pip install -r requirements.txt
```

**Installing Missing Modules**
```bash
# If you encounter ModuleNotFoundError, install the missing module:
# Example: ModuleNotFoundError: No module named 'fastapi'
pip install fastapi

# For async web development:
pip install fastapi uvicorn[standard] httpx
pip install aiohttp aiofiles asyncpg

# For TUI applications:
pip install textual rich typer
pip install prompt-toolkit blessed

# For data processing (Python 3.11 optimized):
pip install numpy pandas polars
pip install pyarrow duckdb

# For testing:
pip install pytest pytest-asyncio pytest-cov
pip install pytest-mock pytest-timeout

# For development:
pip install black ruff mypy
pip install ipython devtools

# Python 3.11 specific features support:
pip install typing-extensions pydantic>=2.0

# Always update requirements.txt after installing:
pip freeze > requirements.txt
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

**Python 3.11 Specific Features**
```python
# Exception groups (install exceptiongroup for backcompat)
pip install exceptiongroup

# Improved error messages - built-in, no install needed

# For task groups in asyncio
import asyncio
# Built-in, no extra install needed

# For tomllib (reading TOML files)
import tomllib  # Built-in since 3.11
# No need to install tomli anymore
```

**Common Package Installation Examples**
```bash
# Modern async frameworks
pip install fastapi uvicorn httpx
pip install starlette pydantic
pip install python-multipart python-jose[cryptography]

# Data validation and serialization
pip install pydantic pydantic-settings
pip install marshmallow cattrs

# Modern CLI tools
pip install typer[all] rich click
pip install textual textual-dev

# Database with async support
pip install sqlalchemy[asyncio] asyncpg
pip install databases aiosqlite
pip install motor  # Async MongoDB

# ML/Data Science (3.11 optimized)
pip install numpy pandas scikit-learn
pip install polars pyarrow
pip install torch tensorflow

# Testing async code
pip install pytest-asyncio anyio
pip install httpx-mock aioresponses

# Performance profiling
pip install scalene memray
pip install py-spy line-profiler
```

**TUI Testing Notes**
- Same venv/symlink issues as Python 3.10
- Use external venv: `python3.11 -m venv ~/venvs/myproject`
- Exception groups provide better error context in tests
