#### Python 3.10

**Environment Setup**
```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Linux/Mac
# .venv\Scripts\activate  # Windows

# Upgrade pip
pip install --upgrade pip
```

**Project Init**
```bash
# Create project structure
mkdir -p src tests docs
touch README.md requirements.txt .gitignore setup.py

# Basic .gitignore
```

Create .gitignore:
```
.venv/
__pycache__/
*.pyc
.coverage
```

```bash
# Initialize as package
touch src/__init__.py
```

**Dependencies**
```bash
# Install from requirements
pip install -r requirements.txt

# Add new dependency
pip install requests
pip freeze > requirements.txt

# Development dependencies
pip install pytest black ruff mypy

# Install project in editable mode
pip install -e .
```

**Installing Missing Modules**
```bash
# If you encounter ModuleNotFoundError, install the missing module:
# Example: ModuleNotFoundError: No module named 'requests'
pip install requests

# For common development tools:
pip install pytest black ruff mypy

# For data science packages:
pip install numpy pandas matplotlib jupyter

# For web frameworks:
pip install flask django fastapi uvicorn

# Always update requirements.txt after installing:
pip freeze > requirements.txt
```

**Format & Lint**
```bash
# Format with black
black src/ tests/

# Lint with ruff
ruff check src/ tests/
ruff check --fix src/ tests/

# Type check with mypy
mypy src/
```

**Testing**
```bash
# Run all tests
pytest

# Verbose with coverage
pytest -v --cov=src --cov-report=term-missing

# Run specific test
pytest tests/test_module.py::test_function

# Run with markers
pytest -m "not slow"
```

**Build**
```bash
# Build distribution packages
pip install build
python -m build

# Creates:
# dist/*.whl (wheel)
# dist/*.tar.gz (source)
```

**Run**
```bash
# Run module
python -m src.main

# Run script
python src/app.py

# Debug mode
python -m pdb src/app.py

# Quick HTTP server
python -m http.server 8000
```

**Common Package Installation Examples**
```bash
# Web development
pip install requests httpx aiohttp
pip install beautifulsoup4 lxml
pip install selenium playwright

# API frameworks
pip install flask flask-restful
pip install fastapi uvicorn[standard]
pip install django djangorestframework

# Data science
pip install numpy pandas scipy
pip install matplotlib seaborn plotly
pip install scikit-learn tensorflow torch

# Testing
pip install pytest pytest-cov pytest-asyncio
pip install unittest-xml-reporting
pip install hypothesis faker

# Development tools
pip install black ruff mypy
pip install ipython ipdb
pip install pre-commit bandit safety

# Database
pip install sqlalchemy psycopg2-binary
pip install pymongo redis
pip install alembic

# Async
pip install asyncio aiofiles
pip install celery[redis]

# CLI tools
pip install click typer rich
pip install python-dotenv pyyaml
```

**TUI Testing Notes**
- Create venv outside project directory to avoid symlink conflicts with TUI Test
- Use `python -m venv ~/venvs/myproject` for external environments
- Or temporarily remove .venv before running TUI tests
