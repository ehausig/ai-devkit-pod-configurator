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
echo ".venv/\n__pycache__/\n*.pyc\n.coverage" > .gitignore

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

**TUI Testing Notes**
- Create venv outside project directory to avoid symlink conflicts with TUI Test
- Use `python -m venv ~/venvs/myproject` for external environments
- Or temporarily remove .venv before running TUI tests
