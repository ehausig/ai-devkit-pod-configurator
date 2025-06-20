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
