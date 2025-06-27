#### Gradle 8.5

**Environment Setup**
```bash
# Gradle uses wrapper - no global install needed
# Wrapper ensures consistent version across team
./gradlew --version
```

**Project Init**
```bash
# Interactive setup
gradle init --type java-application

# Basic Java project
gradle init --type java-library --dsl kotlin

# Spring Boot project
gradle init --type basic
# Then add Spring Boot plugin to build.gradle.kts
```

**Dependencies**
```bash
# Add to build.gradle.kts:
dependencies {
    implementation("com.google.guava:guava:32.1.3-jre")
    testImplementation(kotlin("test"))
}

# Refresh dependencies
./gradlew build --refresh-dependencies

# View dependency tree
./gradlew dependencies
```

**Format & Lint**
```bash
# Add spotless plugin for formatting
# In build.gradle.kts:
plugins {
    id("com.diffplug.spotless") version "6.22.0"
}

# Format code
./gradlew spotlessApply

# Check formatting
./gradlew spotlessCheck
```

**Testing**

*Unit Tests*
```bash
# Run only unit tests
./gradlew test --tests "*Test"

# Run specific test class
./gradlew test --tests "com.example.CalculatorTest"

# Continuous testing
./gradlew test --continuous
```

*Integration Tests*
```bash
# Configure separate source set in build.gradle.kts
sourceSets {
    create("integrationTest") {
        kotlin.srcDir("src/integrationTest/kotlin")
        java.srcDir("src/integrationTest/java")
        resources.srcDir("src/integrationTest/resources")
        compileClasspath += main.output + test.output
        runtimeClasspath += main.output + test.output
    }
}

# Run integration tests
./gradlew integrationTest

# Run with test containers
./gradlew integrationTest -Dspring.profiles.active=test
```

*User Simulation Tests*
```bash
# E2E test configuration
task e2eTest(type: Test) {
    testClassesDirs = sourceSets.e2e.output.classesDirs
    classpath = sourceSets.e2e.runtimeClasspath
}

# Run E2E tests
./gradlew e2eTest

# Run all test types in order
./gradlew test integrationTest e2eTest
```

*Test Reports*
```bash
# Generate unified test report
./gradlew testReport

# Coverage with JaCoCo
./gradlew test jacocoTestReport

# View reports
open build/reports/tests/test/index.html
open build/reports/jacoco/test/html/index.html
```

**Build**
```bash
# Clean and build
./gradlew clean build

# Build without tests
./gradlew build -x test

# Parallel build
./gradlew build --parallel
```

**Run**
```bash
# Run application
./gradlew run

# Run with arguments
./gradlew run --args="arg1 arg2"

# Run with debug info
./gradlew run --info

# Create executable JAR
./gradlew jar
java -jar build/libs/myapp.jar
```
