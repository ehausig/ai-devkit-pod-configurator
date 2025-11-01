#!/bin/bash
# Test Maven installation and dependency resolution
set -e

echo "Testing Maven installation and dependency resolution..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test basic Maven POM
echo "Creating test Maven project..."
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>test-project</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <name>Test Project</name>
    <description>A test project for Maven</description>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>com.google.guava</groupId>
            <artifactId>guava</artifactId>
            <version>31.1-jre</version>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Test dependency resolution
echo "Testing dependency resolution..."
if mvn dependency:resolve -q > /dev/null 2>&1; then
    echo "✅ Runtime dependencies resolved"
else
    echo "❌ Failed to resolve runtime dependencies"
    exit 1
fi

if mvn dependency:resolve -Dclassifier=test-compile -q > /dev/null 2>&1; then
    echo "✅ Test dependencies resolved"
else
    echo "❌ Failed to resolve test dependencies"
    exit 1
fi

# Test dependency tree
echo "Testing dependency tree..."
if mvn dependency:tree -q > /dev/null 2>&1; then
    echo "✅ Dependency tree generation working"
else
    echo "❌ Dependency tree generation failed"
    exit 1
fi

# Test effective POM
echo "Testing effective POM..."
if mvn help:effective-pom -q > /dev/null 2>&1; then
    echo "✅ Effective POM generation working"
else
    echo "❌ Effective POM generation failed"
    exit 1
fi

# Create source files for compilation test
mkdir -p src/main/java/com/example
cat > src/main/java/com/example/Main.java << 'EOF'
package com.example;

import com.google.common.collect.Lists;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> list = Lists.newArrayList("Hello", "Maven", "World");
        System.out.println(String.join(" ", list));
    }
    
    public String getGreeting() {
        return "Hello from Maven!";
    }
}
EOF

# Test compilation with dependencies
echo "Testing compilation with dependencies..."
if mvn compile -q > /dev/null 2>&1; then
    echo "✅ Compilation with dependencies working"
else
    echo "❌ Compilation with dependencies failed"
    exit 1
fi

# Create test files
mkdir -p src/test/java/com/example
cat > src/test/java/com/example/MainTest.java << 'EOF'
package com.example;

import org.junit.Test;
import static org.junit.Assert.*;

public class MainTest {
    @Test
    public void testGetGreeting() {
        Main main = new Main();
        String greeting = main.getGreeting();
        assertEquals("Hello from Maven!", greeting);
    }
    
    @Test
    public void testBasic() {
        assertTrue("Basic test", true);
    }
}
EOF

# Test test compilation
echo "Testing test compilation..."
if mvn test-compile -q > /dev/null 2>&1; then
    echo "✅ Test compilation working"
else
    echo "❌ Test compilation failed"
    exit 1
fi

# Test repository access and caching
echo "Testing repository access..."
if mvn dependency:copy-dependencies -DoutputDirectory=target/lib -q > /dev/null 2>&1; then
    echo "✅ Repository access and dependency download working"
    if [[ -d target/lib ]] && [[ $(ls -1 target/lib/*.jar | wc -l) -gt 0 ]]; then
        echo "✅ Dependencies copied to target directory"
    fi
else
    echo "❌ Repository access failed"
    exit 1
fi

# Test plugin resolution
echo "Testing plugin resolution..."
if mvn help:describe -Dplugin=compiler -q > /dev/null 2>&1; then
    echo "✅ Plugin resolution working"
else
    echo "❌ Plugin resolution failed"
    exit 1
fi

# Test validate phase
echo "Testing project validation..."
if mvn validate -q > /dev/null 2>&1; then
    echo "✅ Project validation working"
else
    echo "❌ Project validation failed"
    exit 1
fi

# Test dependency analysis
echo "Testing dependency analysis..."
if mvn dependency:analyze -q > /dev/null 2>&1; then
    echo "✅ Dependency analysis working"
else
    echo "❌ Dependency analysis failed"
    exit 1
fi

# Test with different scopes
cat >> pom.xml << 'EOF'
        <dependency>
            <groupId>javax.servlet</groupId>
            <artifactId>javax.servlet-api</artifactId>
            <version>4.0.1</version>
            <scope>provided</scope>
        </dependency>
EOF

echo "Testing provided scope dependencies..."
if mvn dependency:resolve -q > /dev/null 2>&1; then
    echo "✅ Provided scope dependencies working"
else
    echo "❌ Provided scope dependencies failed"
    exit 1
fi

# Test Maven wrapper (if available)
if command -v mvn &> /dev/null; then
    echo "Testing Maven wrapper creation..."
    if mvn -N wrapper:wrapper -q > /dev/null 2>&1; then
        echo "✅ Maven wrapper created"
        if [[ -f mvnw ]]; then
            echo "✅ mvnw script created"
        fi
    else
        echo "ℹ️  Maven wrapper plugin not available"
    fi
fi

echo "✅ All Maven installation and dependency tests passed"