#### Java 17 (Eclipse Adoptium Temurin)

**Environment Setup**
```bash
# Verify Adoptium Java 17
java -version  # Should show "Temurin"
javac -version

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/temurin-17
```

**Project Init**
```bash
# Modern Spring Boot 3.x
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp \
  -DarchetypeArtifactId=spring-boot-starter-parent \
  -DarchetypeVersion=3.2.0

# Gradle with Java 17
gradle init --type java-application --dsl kotlin \
  --java-version 17 --project-name myapp
```

**Dependencies**
```bash
# Maven - Java 17 features
<properties>
    <java.version>17</java.version>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
</properties>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>3.2.0</version>
</dependency>
```

**Format & Lint**
```bash
# Spotless with Java 17 support
mvn spotless:apply

# Error Prone for additional checks
# Add to pom.xml compiler plugin

# Modern formatting
java -jar google-java-format.jar --aosp src/**/*.java
```

**Testing**
```bash
# JUnit 5 with Java 17 features
@Test
void testRecords() {
    record Person(String name, int age) {}
    var person = new Person("Alice", 30);
    assertEquals("Alice", person.name());
}

# Parameterized tests
@ParameterizedTest
@ValueSource(strings = {"hello", "world"})
void testWithParams(String value) {
    assertNotNull(value);
}
```

**Build**
```bash
# Enable text blocks and records
mvn clean package

# With ZGC for low latency
mvn package -DargLine="-XX:+UseZGC"

# Gradle
./gradlew build --no-daemon
```

**Run**
```bash
# Run with ZGC (low latency)
java -XX:+UseZGC -jar myapp.jar

# Run with G1GC (balanced)
java -XX:+UseG1GC -jar myapp.jar

# Spring Boot
mvn spring-boot:run
./gradlew bootRun
```
