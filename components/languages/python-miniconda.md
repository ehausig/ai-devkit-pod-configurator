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
