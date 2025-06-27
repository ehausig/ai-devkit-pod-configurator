#### Java 17 (OpenJDK)

**Environment Setup**
```bash
# Java doesn't use virtual environments
java -version  # Verify Java 17
javac -version

# Set JAVA_HOME if needed
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
```

**Project Init**
```bash
# Maven project
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false

# Gradle project
gradle init --type java-application --dsl kotlin

# Manual structure
mkdir -p src/main/java/com/example src/test/java/com/example
```

**Dependencies**
```bash
# Maven (pom.xml)
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>3.2.0</version>
</dependency>

# Gradle (build.gradle.kts)
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web:3.2.0")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
}
```

**Format & Lint**
```bash
# Maven with Spotless
mvn spotless:apply  # Format
mvn spotless:check  # Check

# Gradle with Spotless
./gradlew spotlessApply
./gradlew spotlessCheck

# Google Java Format
java -jar google-java-format.jar --replace src/**/*.java
```

**Testing**

*Unit Tests*
```bash
# Maven
mvn test -Dtest="*UnitTest"
mvn test -Dtest=CalculatorTest#testAdd

# Gradle
./gradlew test --tests "*UnitTest"

# JUnit 5 example
// src/test/java/com/example/CalculatorTest.java
@Test
void testAdd() {
    assertEquals(5, Calculator.add(2, 3));
}

@ParameterizedTest
@ValueSource(ints = {1, 2, 3})
void testPositive(int number) {
    assertTrue(number > 0);
}
```

*Integration Tests*
```bash
# Maven (using Failsafe plugin)
mvn verify -Dit.test="*IT"

# Spring Boot integration test
// src/test/java/com/example/UserServiceIT.java
@SpringBootTest
@AutoConfigureMockMvc
class UserServiceIT {
    @Autowired
    private MockMvc mockMvc;
    
    @Test
    @Sql("/test-data.sql")
    void testCreateUser() throws Exception {
        mockMvc.perform(post("/api/users")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"test@example.com\"}"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").exists());
    }
}

# TestContainers for database
@Testcontainers
class DatabaseIT {
    @Container
    PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    
    @Test
    void testWithRealDatabase() {
        String jdbcUrl = postgres.getJdbcUrl();
        // Test with real database
    }
}
```

*User Simulation Tests*
```bash
# TUI testing with Microsoft TUI Test
npx @microsoft/tui-test src/test/e2e/

# Selenium WebDriver
mvn test -Dtest="*E2ETest"

# Example: Selenium test
// src/test/java/com/example/LoginE2ETest.java
@Test
void testLoginFlow() {
    WebDriver driver = new ChromeDriver();
    driver.get("http://localhost:8080");
    driver.findElement(By.name("email")).sendKeys("user@example.com");
    driver.findElement(By.name("password")).sendKeys("password");
    driver.findElement(By.cssSelector("button[type='submit']")).click();
    
    assertEquals("http://localhost:8080/dashboard", driver.getCurrentUrl());
    driver.quit();
}
```

**Build**
```bash
# Maven
mvn clean package
mvn clean install  # Install to local repo

# Gradle
./gradlew clean build
./gradlew jar

# Direct compilation
javac -d out src/main/java/com/example/*.java
jar cf myapp.jar -C out .
```

**Run**
```bash
# Maven
mvn exec:java -Dexec.mainClass="com.example.Main"

# Gradle
./gradlew run

# Direct execution
java -cp target/myapp.jar com.example.Main

# Single file (Java 11+)
java MyProgram.java
```
