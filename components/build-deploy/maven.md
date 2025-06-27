#### Maven

**Environment Setup**
```bash
# Maven uses wrapper or global install
mvn -version

# Install wrapper
mvn wrapper:wrapper
./mvnw --version
```

**Project Init**
```bash
# Interactive archetype selection
mvn archetype:generate

# Quick start Java app
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp \
  -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false

# Spring Boot app
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp \
  -DarchetypeArtifactId=spring-boot-starter-parent
```

**Dependencies**
```bash
# Add to pom.xml:
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>3.2.0</version>
</dependency>

# Force update dependencies
mvn clean install -U

# Display dependency tree
mvn dependency:tree
mvn dependency:tree -Dverbose  # Show conflicts
```

**Format & Lint**
```bash
# Add Spotless plugin to pom.xml
<plugin>
    <groupId>com.diffplug.spotless</groupId>
    <artifactId>spotless-maven-plugin</artifactId>
</plugin>

# Format code
mvn spotless:apply

# Check formatting
mvn spotless:check
```

**Testing**

*Unit Tests*
```bash
# Run unit tests only (Surefire plugin)
mvn test

# Run specific test
mvn test -Dtest=CalculatorTest
mvn test -Dtest=CalculatorTest#testAddition

# Skip tests during build
mvn package -DskipTests
```

*Integration Tests*
```bash
# Configure Failsafe plugin in pom.xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-failsafe-plugin</artifactId>
    <version>3.2.5</version>
    <executions>
        <execution>
            <goals>
                <goal>integration-test</goal>
                <goal>verify</goal>
            </goals>
        </execution>
    </executions>
</plugin>

# Run integration tests (*IT.java files)
mvn verify

# Run specific integration test
mvn verify -Dit.test=UserServiceIT
```

*User Simulation Tests*
```bash
# E2E tests with separate profile
mvn test -Pend-to-end

# Configure in pom.xml
<profile>
    <id>end-to-end</id>
    <build>
        <plugins>
            <plugin>
                <artifactId>maven-surefire-plugin</artifactId>
                <configuration>
                    <includes>
                        <include>**/*E2E.java</include>
                    </includes>
                </configuration>
            </plugin>
        </plugins>
    </build>
</profile>

# Run all test phases
mvn clean test verify
```

*Test Reports*
```bash
# Test reports location
# target/surefire-reports/ (unit tests)
# target/failsafe-reports/ (integration tests)

# Generate site with reports
mvn site

# Coverage with JaCoCo
mvn test jacoco:report
open target/site/jacoco/index.html
```

**Build**
```bash
# Clean and package
mvn clean package

# Install to local repo
mvn clean install

# Build without tests
mvn package -DskipTests

# Multi-threaded build
mvn -T 4 clean package
```

**Run**
```bash
# Run main class
mvn exec:java -Dexec.mainClass="com.example.Main"

# Run with arguments
mvn exec:java -Dexec.mainClass="com.example.Main" -Dexec.args="arg1 arg2"

# Spring Boot
mvn spring-boot:run

# Run JAR
java -jar target/myapp.jar
```
