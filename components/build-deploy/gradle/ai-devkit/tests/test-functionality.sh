#!/bin/bash
# Test Gradle build functionality
set -e

echo "Testing Gradle build functionality..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test gradle init command
echo "Testing gradle init..."
if gradle init --type java-application --dsl groovy --test-framework junit --project-name test-app --package com.example --no-split-project --quiet > /dev/null 2>&1; then
    echo "✅ Gradle init (Java application) working"
else
    echo "❌ Gradle init failed"
    exit 1
fi

# Verify generated structure
if [[ -f build.gradle && -d src/main/java && -d src/test/java ]]; then
    echo "✅ Project structure generated correctly"
else
    echo "❌ Project structure not generated correctly"
    exit 1
fi

# Test compilation
echo "Testing compilation..."
if gradle compileJava --quiet > /dev/null 2>&1; then
    echo "✅ Compilation working"
else
    echo "❌ Compilation failed"
    exit 1
fi

# Test running tests
echo "Testing test execution..."
if gradle test --quiet > /dev/null 2>&1; then
    echo "✅ Test execution working"
else
    echo "❌ Test execution failed"
    exit 1
fi

# Test JAR creation
echo "Testing JAR creation..."
if gradle jar --quiet > /dev/null 2>&1; then
    echo "✅ JAR creation working"
    if [[ -f build/libs/test-app.jar ]]; then
        echo "✅ JAR file created at expected location"
    else
        echo "❌ JAR file not found at expected location"
        exit 1
    fi
else
    echo "❌ JAR creation failed"
    exit 1
fi

# Test application execution
echo "Testing application execution..."
if gradle run --quiet > /dev/null 2>&1; then
    echo "✅ Application execution working"
else
    echo "❌ Application execution failed"
    exit 1
fi

# Test clean task
echo "Testing clean task..."
if gradle clean --quiet > /dev/null 2>&1; then
    echo "✅ Clean task working"
    if [[ ! -d build ]]; then
        echo "✅ Build directory cleaned"
    fi
else
    echo "❌ Clean task failed"
    exit 1
fi

# Test multi-project build
echo "Testing multi-project build..."
mkdir -p subproject
cat > settings.gradle << 'EOF'
rootProject.name = 'multi-project-test'
include 'subproject'
EOF

cat > subproject/build.gradle << 'EOF'
apply plugin: 'java'

repositories {
    mavenCentral()
}
EOF

mkdir -p subproject/src/main/java/sub
cat > subproject/src/main/java/sub/SubClass.java << 'EOF'
package sub;

public class SubClass {
    public String getMessage() {
        return "Hello from subproject";
    }
}
EOF

# Update main build.gradle to depend on subproject
cat > build.gradle << 'EOF'
plugins {
    id 'java'
    id 'application'
}

repositories {
    mavenCentral()
}

dependencies {
    implementation project(':subproject')
    testImplementation 'junit:junit:4.13.2'
}

application {
    mainClass = 'com.example.App'
}
EOF

# Update main class to use subproject
mkdir -p src/main/java/com/example
cat > src/main/java/com/example/App.java << 'EOF'
package com.example;

import sub.SubClass;

public class App {
    public String getGreeting() {
        SubClass sub = new SubClass();
        return sub.getMessage();
    }

    public static void main(String[] args) {
        System.out.println(new App().getGreeting());
    }
}
EOF

if gradle build --quiet > /dev/null 2>&1; then
    echo "✅ Multi-project build working"
else
    echo "❌ Multi-project build failed"
    exit 1
fi

# Test dependency insights
echo "Testing dependency insights..."
if gradle dependencyInsight --dependency junit --quiet > /dev/null 2>&1; then
    echo "✅ Dependency insights working"
else
    echo "❌ Dependency insights failed"
    exit 1
fi

# Test build with different tasks
echo "Testing various build tasks..."
gradle_tasks=("assemble" "build" "check")
for task in "${gradle_tasks[@]}"; do
    if gradle "$task" --quiet > /dev/null 2>&1; then
        echo "✅ Task '$task' working"
    else
        echo "❌ Task '$task' failed"
        exit 1
    fi
done

# Test Gradle properties
echo "Testing Gradle properties..."
cat > gradle.properties << 'EOF'
org.gradle.daemon=true
org.gradle.parallel=true
test.property=test-value
EOF

if gradle properties --quiet | grep -q "test.property"; then
    echo "✅ Gradle properties working"
else
    echo "❌ Gradle properties not working"
    exit 1
fi

# Test custom task with dependencies
cat >> build.gradle << 'EOF'

task customTask {
    dependsOn compileJava
    doLast {
        println 'Custom task executed after compilation'
    }
}
EOF

echo "Testing custom task with dependencies..."
if gradle customTask --quiet | grep -q "Custom task executed"; then
    echo "✅ Custom task with dependencies working"
else
    echo "❌ Custom task with dependencies failed"
    exit 1
fi

# Test build cache (if available)
echo "Testing build cache..."
if gradle clean build --build-cache --quiet > /dev/null 2>&1; then
    echo "✅ Build cache working"
else
    echo "ℹ️  Build cache not available or disabled"
fi

echo "✅ All Gradle functionality tests passed"