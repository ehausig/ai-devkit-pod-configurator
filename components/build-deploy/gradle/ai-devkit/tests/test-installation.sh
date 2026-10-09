#!/bin/bash
# Test Gradle installation and dependency resolution
set -e

echo "Testing Gradle installation and dependency resolution..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test basic Gradle build script
echo "Creating test Gradle project..."
cat > build.gradle << 'EOF'
apply plugin: 'java'

repositories {
    mavenCentral()
}

dependencies {
    testImplementation 'junit:junit:4.13.2'
    implementation 'com.google.guava:guava:31.1-jre'
}

task hello {
    doLast {
        println 'Hello from Gradle!'
    }
}
EOF

# Test gradle wrapper initialization
echo "Testing Gradle wrapper..."
if gradle wrapper --gradle-version=current > /dev/null 2>&1; then
    echo "✅ Gradle wrapper created successfully"
    if [[ -f gradlew ]]; then
        echo "✅ gradlew script created"
    fi
    if [[ -d gradle/wrapper ]]; then
        echo "✅ Gradle wrapper directory created"
    fi
else
    echo "❌ Failed to create Gradle wrapper"
    exit 1
fi

# Test dependency resolution
echo "Testing dependency resolution..."
if gradle dependencies --configuration=compileClasspath --quiet > /dev/null 2>&1; then
    echo "✅ Compile dependencies resolved"
else
    echo "❌ Failed to resolve compile dependencies"
    exit 1
fi

if gradle dependencies --configuration=testCompileClasspath --quiet > /dev/null 2>&1; then
    echo "✅ Test dependencies resolved"
else
    echo "❌ Failed to resolve test dependencies"
    exit 1
fi

# Test custom task execution
echo "Testing custom task execution..."
if gradle hello --quiet | grep -q "Hello from Gradle!"; then
    echo "✅ Custom task execution working"
else
    echo "❌ Custom task execution failed"
    exit 1
fi

# Test downloading dependencies
echo "Testing dependency download..."
if gradle build --dry-run --quiet > /dev/null 2>&1; then
    echo "✅ Build dry-run working"
else
    echo "❌ Build dry-run failed"
    exit 1
fi

# Create source files for compilation test
mkdir -p src/main/java/test
cat > src/main/java/test/Main.java << 'EOF'
package test;

import com.google.common.collect.Lists;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> list = Lists.newArrayList("Hello", "Gradle", "World");
        System.out.println(String.join(" ", list));
    }
}
EOF

# Test compilation with dependencies
echo "Testing compilation with dependencies..."
if gradle compileJava --quiet > /dev/null 2>&1; then
    echo "✅ Compilation with dependencies working"
else
    echo "❌ Compilation with dependencies failed"
    exit 1
fi

# Test creating test files
mkdir -p src/test/java/test
cat > src/test/java/test/MainTest.java << 'EOF'
package test;

import org.junit.Test;
import static org.junit.Assert.*;

public class MainTest {
    @Test
    public void testBasic() {
        assertTrue("Basic test", true);
    }
}
EOF

# Test test compilation
echo "Testing test compilation..."
if gradle compileTestJava --quiet > /dev/null 2>&1; then
    echo "✅ Test compilation working"
else
    echo "❌ Test compilation failed"
    exit 1
fi

# Test repository access
echo "Testing repository access..."
if gradle dependencies --configuration=runtimeClasspath --quiet | grep -q "guava"; then
    echo "✅ Repository access and dependency download working"
else
    echo "❌ Repository access failed"
    exit 1
fi

# Test plugin application
cat > build.gradle << 'EOF'
plugins {
    id 'java'
    id 'application'
}

repositories {
    mavenCentral()
}

dependencies {
    implementation 'com.google.guava:guava:31.1-jre'
}

application {
    mainClass = 'test.Main'
}
EOF

echo "Testing plugin application..."
if gradle build --dry-run --quiet > /dev/null 2>&1; then
    echo "✅ Plugin application working"
else
    echo "❌ Plugin application failed"
    exit 1
fi

echo "✅ All Gradle installation and dependency tests passed"