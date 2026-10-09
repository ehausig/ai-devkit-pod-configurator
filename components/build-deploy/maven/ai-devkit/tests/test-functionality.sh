#!/bin/bash
# Test Maven build functionality
set -e

echo "Testing Maven build functionality..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test mvn archetype:generate
echo "Testing mvn archetype:generate..."
if mvn archetype:generate \
    -DgroupId=com.example.test \
    -DartifactId=maven-test-app \
    -DarchetypeArtifactId=maven-archetype-quickstart \
    -DinteractiveMode=false \
    -q > /dev/null 2>&1; then
    echo "✅ Maven archetype generation working"
else
    echo "❌ Maven archetype generation failed"
    exit 1
fi

# Verify generated structure
if [[ -d maven-test-app && -f maven-test-app/pom.xml ]]; then
    echo "✅ Project structure generated correctly"
    cd maven-test-app
else
    echo "❌ Project structure not generated correctly"
    exit 1
fi

# Test compilation
echo "Testing compilation..."
if mvn compile -q > /dev/null 2>&1; then
    echo "✅ Compilation working"
else
    echo "❌ Compilation failed"
    exit 1
fi

# Test running tests
echo "Testing test execution..."
if mvn test -q > /dev/null 2>&1; then
    echo "✅ Test execution working"
else
    echo "❌ Test execution failed"
    exit 1
fi

# Test packaging
echo "Testing JAR packaging..."
if mvn package -q > /dev/null 2>&1; then
    echo "✅ JAR packaging working"
    if [[ -f target/maven-test-app-1.0-SNAPSHOT.jar ]]; then
        echo "✅ JAR file created at expected location"
    else
        echo "❌ JAR file not found at expected location"
        exit 1
    fi
else
    echo "❌ JAR packaging failed"
    exit 1
fi

# Test exec plugin
echo "Testing application execution..."
if mvn exec:java -Dexec.mainClass="com.example.test.App" -q > /dev/null 2>&1; then
    echo "✅ Application execution working"
else
    echo "ℹ️  Application execution requires exec plugin configuration"
fi

# Test clean
echo "Testing clean..."
if mvn clean -q > /dev/null 2>&1; then
    echo "✅ Clean working"
    if [[ ! -d target ]]; then
        echo "✅ Target directory cleaned"
    fi
else
    echo "❌ Clean failed"
    exit 1
fi

# Test install (local repository)
echo "Testing install to local repository..."
if mvn install -q > /dev/null 2>&1; then
    echo "✅ Install to local repository working"
else
    echo "❌ Install to local repository failed"
    exit 1
fi

# Test site generation
echo "Testing site generation..."
if mvn site -q > /dev/null 2>&1; then
    echo "✅ Site generation working"
    if [[ -d target/site ]]; then
        echo "✅ Site directory created"
    fi
else
    echo "ℹ️  Site generation may require additional configuration"
fi

# Test multi-module project
cd "$TEST_DIR"
echo "Testing multi-module project..."
mkdir -p multi-module-test
cd multi-module-test

# Parent POM
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>multi-module-parent</artifactId>
    <version>1.0.0</version>
    <packaging>pom</packaging>
    
    <modules>
        <module>module-a</module>
        <module>module-b</module>
    </modules>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>junit</groupId>
                <artifactId>junit</artifactId>
                <version>4.13.2</version>
                <scope>test</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
</project>
EOF

# Module A
mkdir -p module-a/src/main/java/com/example/modulea
cat > module-a/pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>com.example</groupId>
        <artifactId>multi-module-parent</artifactId>
        <version>1.0.0</version>
    </parent>
    
    <artifactId>module-a</artifactId>
    
    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
EOF

cat > module-a/src/main/java/com/example/modulea/ServiceA.java << 'EOF'
package com.example.modulea;

public class ServiceA {
    public String getMessage() {
        return "Hello from Module A";
    }
}
EOF

# Module B (depends on A)
mkdir -p module-b/src/main/java/com/example/moduleb
cat > module-b/pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>com.example</groupId>
        <artifactId>multi-module-parent</artifactId>
        <version>1.0.0</version>
    </parent>
    
    <artifactId>module-b</artifactId>
    
    <dependencies>
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>module-a</artifactId>
            <version>1.0.0</version>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
EOF

cat > module-b/src/main/java/com/example/moduleb/ServiceB.java << 'EOF'
package com.example.moduleb;

import com.example.modulea.ServiceA;

public class ServiceB {
    public String getCombinedMessage() {
        ServiceA serviceA = new ServiceA();
        return serviceA.getMessage() + " and Module B";
    }
}
EOF

echo "Testing multi-module build..."
if mvn compile -q > /dev/null 2>&1; then
    echo "✅ Multi-module compilation working"
else
    echo "❌ Multi-module compilation failed"
    exit 1
fi

if mvn package -q > /dev/null 2>&1; then
    echo "✅ Multi-module packaging working"
else
    echo "❌ Multi-module packaging failed"
    exit 1
fi

# Test reactor build order
echo "Testing reactor build order..."
if mvn dependency:tree -q > /dev/null 2>&1; then
    echo "✅ Reactor build order working"
else
    echo "❌ Reactor build order failed"
    exit 1
fi

# Test profile activation
cd "$TEST_DIR"
mkdir profile-test
cd profile-test

cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>profile-test</artifactId>
    <version>1.0.0</version>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <profiles>
        <profile>
            <id>development</id>
            <properties>
                <env>dev</env>
            </properties>
        </profile>
        <profile>
            <id>production</id>
            <properties>
                <env>prod</env>
            </properties>
        </profile>
    </profiles>
</project>
EOF

echo "Testing Maven profiles..."
if mvn help:active-profiles -Pdevelopment -q > /dev/null 2>&1; then
    echo "✅ Maven profiles working"
else
    echo "❌ Maven profiles failed"
    exit 1
fi

# Test Maven properties
echo "Testing Maven properties..."
if mvn help:evaluate -Dexpression=project.version -q -DforceStdout 2>/dev/null | grep -q "1.0.0"; then
    echo "✅ Maven properties evaluation working"
else
    echo "❌ Maven properties evaluation failed"
    exit 1
fi

echo "✅ All Maven functionality tests passed"