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
