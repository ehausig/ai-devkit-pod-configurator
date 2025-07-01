# Comprehensive Hook Testing Prompts

## 1. Test Session Tracker Hook

Let's start by creating a new project called "hook-test" in the workspace. First, change to the workspace directory and show me the current working directory. Then create the project folder and change into it.

## 2. Test Project Lifecycle Hook

Now let's initialize a git repository in this hook-test project, create a README file, and make our first commit. Then create a develop branch. 

## 3. Test Enhanced Bash Logger Categories

Let's test different command categories. Run these commands:

1. First, create a project structure:
   mkdir -p src tests/unit tests/integration docs

2. Then initialize npm:
   npm init -y

3. Install a package:
   npm install express

4. Run a git status:
   git status

5. Check disk usage:
   df -h

## 4. Test Decision Tracker Hook

Create a Python project setup with these files:

1. Create requirements.txt with Flask dependencies:

Create requirements.txt:
```
flask==2.3.0
pytest==7.4.0
black==23.0.0
```

2. Create a simple Flask app:

Create src/app.py:
```python
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello World!"
```

3. Create a Dockerfile for the project:

Create Dockerfile:
```dockerfile
FROM python:3.11
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "src/app.py"]
```

## 5. Test File Milestone Tracker

Let's create some important project files:

1. Create a proper README:

Create README.md:
```markdown
# Hook Test Project
This project tests the Claude Code hooks system.
```

2. Add a license:

Create LICENSE:
```
MIT License
```

3. Create a gitignore:

Create .gitignore:
```
*.pyc
__pycache__/
.env
venv/
```

4. Add a changelog:

Create CHANGELOG.md:
```markdown
# Changelog
## [0.1.0] - 2024-01-01
- Initial release
```

## 6. Test Test Tracker Hook

Let's create and run some tests:

1. First create a test file:

Create tests/unit/test_app.py:
```python
def test_hello():
    assert 1 + 1 == 2
```

2. Run pytest (it might not be installed, that's ok):
   pytest tests/unit/test_app.py

3. Try running with coverage:
   pytest --cov=src tests/

4. For Node.js style:
   npm test

Show me the JOURNAL.md to see the test tracking.

## 7. Test Error Recovery Hook

Let's intentionally cause some errors to test error tracking:

1. Try to list a non-existent directory:
   ls /nonexistent/directory

2. Try a git operation that will fail:
   git push origin main

3. Try to install a package that doesn't exist:
   pip install this-package-definitely-does-not-exist-12345

4. Now let's do a recovery - force install something:
   pip install requests --force-reinstall

## 8. Test Project Lifecycle - GitHub Operations

Try to create a GitHub repository (this might fail if not authenticated, which is fine for testing):

gh repo create hook-test --public --description "Testing hooks"

Then simulate a PR creation command:
gh pr create --title "feat: add hooks" --body "Testing PR creation"

## 9. Test Format Code Hook

Create some badly formatted Python and JavaScript files:

Create bad_format.py:
```python
def hello(   name   ):
    print(  "Hello, "   +name)
    if name=="World":
        print("Welcome!")
```

Create bad_format.js:
```javascript
function greet(name){console.log("Hello "+name);if(name==="World"){console.log("Welcome!")}}
```

After creating these, check JOURNAL.md for auto-formatting attempts.

## 10. Test Notification Hook

Let's trigger a notification by trying to write to a protected location:

sudo echo "test" > /etc/test.txt

Or try to access the .claude directory:
cat ~/.claude/settings.json > /tmp/settings-backup.json

Then check both JOURNAL.md and ~/.notifications.log

## 11. Comprehensive Verification

Now let's do a final check of all the hooks:

1. Show me the hooks directory:
   ls -la ~/.claude/hooks/

2. Count the hook scripts:
   ls ~/.claude/hooks/*.sh | wc -l

3. Show the JOURNAL.md with all our test entries:
   cat ~/workspace/JOURNAL.md | tail -50

4. Check if we have a notifications log:
   cat ~/workspace/.notifications.log 2>/dev/null || echo "No notifications log yet"

5. Verify hooks are in settings:
   grep -A 5 '"hooks":' ~/.claude/settings.json

## 12. Test Stop Hook

Great! All the hooks seem to be working. Let's end this session now to test the Stop hook. When I start a new session, we can check if the session completion was logged.

Goodbye!
