#### Java 11 (OpenJDK)

**Environment Setup**
```bash
# Java doesn't use virtual environments
java -version  # Verify Java 11
javac -version

# Set JAVA_HOME if needed
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
```

**Project Init**
```bash
# Maven quickstart
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp \
  -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false

# Gradle project
gradle init --type java-application

# Basic structure
mkdir -p src/main/java/com/example src/test/java/com/example
```

**Dependencies**
```bash
# Maven (pom.xml)
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>2.7.18</version>  <!-- Latest for Java 11 -->
</dependency>

# Gradle (build.gradle)
dependencies {
    implementation 'com.squareup.okhttp3:okhttp:4.12.0'
    testImplementation 'junit:junit:4.13.2'
}
```

**Format & Lint**
```bash
# Google Java Format
wget https://github.com/google/google-java-format/releases/download/v1.19.1/google-java-format-1.19.1-all-deps.jar
java -jar google-java-format-1.19.1-all-deps.jar --replace src/**/*.java

# Checkstyle
mvn checkstyle:check
```

**Testing**

*Unit Tests*
```bash
# Maven unit tests
mvn test -Dtest="*Test"

# Gradle unit tests
./gradlew test --tests "*Test"

# JUnit 5 example with Java 11 features
// src/test/java/CalculatorTest.java
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CalculatorTest {
    @Test
    void testAddition() {
        var calculator = new Calculator();  // Java 11 var
        assertEquals(5, calculator.add(2, 3));
    }
    
    @Test
    void testStringMethods() {
        // Java 11 String methods
        assertTrue("  ".isBlank());
        assertEquals("Hello\nWorld", "Hello\nWorld".lines().collect(Collectors.joining("\n")));
        assertEquals("abc", "abc".repeat(1));
    }
}

// Parameterized tests
@ParameterizedTest
@CsvSource({
    "2, 3, 5",
    "-1, 1, 0",
    "0, 0, 0"
})
void testAddWithMultipleInputs(int a, int b, int expected) {
    assertEquals(expected, new Calculator().add(a, b));
}
```

*Integration Tests*
```bash
# Spring Boot 2.x integration
mvn verify -Dit.test="*IT"

// src/test/java/UserControllerIT.java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
class UserControllerIT {
    @Autowired
    private MockMvc mockMvc;
    
    @Autowired
    private UserRepository userRepository;
    
    @Test
    @Transactional
    @Rollback
    void testCreateUser() throws Exception {
        mockMvc.perform(post("/api/users")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"test@example.com\"}"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").exists());
            
        // Verify in database
        var users = userRepository.findByEmail("test@example.com");
        assertFalse(users.isEmpty());
    }
}

// HTTP Client integration test
@Test
void testExternalApiIntegration() throws Exception {
    var client = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(10))
        .build();
        
    var request = HttpRequest.newBuilder()
        .uri(URI.create("https://api.example.com/data"))
        .timeout(Duration.ofSeconds(5))
        .build();
        
    var response = client.send(request, HttpResponse.BodyHandlers.ofString());
    assertEquals(200, response.statusCode());
    assertNotNull(response.body());
}
```

*User Simulation Tests*
```bash
# TUI testing
npx @microsoft/tui-test src/test/e2e/

# Selenium E2E tests
mvn test -Dtest="*E2E"

// src/test/java/LoginE2E.java
import org.openqa.selenium.*;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.support.ui.WebDriverWait;

class LoginE2E {
    @Test
    void testFullUserFlow() {
        System.setProperty("webdriver.chrome.driver", "drivers/chromedriver");
        WebDriver driver = new ChromeDriver();
        var wait = new WebDriverWait(driver, Duration.ofSeconds(10));
        
        try {
            // Navigate to app
            driver.get("http://localhost:8080");
            
            // Login
            driver.findElement(By.name("email")).sendKeys("user@example.com");
            driver.findElement(By.name("password")).sendKeys("password");
            driver.findElement(By.cssSelector("button[type='submit']")).click();
            
            // Wait for dashboard
            wait.until(ExpectedConditions.urlContains("/dashboard"));
            
            // Interact with dashboard
            driver.findElement(By.linkText("Profile")).click();
            wait.until(ExpectedConditions.presenceOfElementLocated(By.id("profile-form")));
            
            // Verify profile page
            var profileTitle = driver.findElement(By.tagName("h1")).getText();
            assertTrue(profileTitle.contains("Profile"));
            
        } finally {
            driver.quit();
        }
    }
}

// REST API E2E test
@Test
void testApiWorkflow() {
    var client = HttpClient.newHttpClient();
    
    // Create user
    var createRequest = HttpRequest.newBuilder()
        .uri(URI.create("http://localhost:8080/api/users"))
        .header("Content-Type", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString(
            "{\"email\":\"test@example.com\"}"
        ))
        .build();
        
    var createResponse = client.sendAsync(createRequest, HttpResponse.BodyHandlers.ofString())
        .join();
        
    assertEquals(201, createResponse.statusCode());
}
```

**Build**
```bash
# Maven
mvn clean package
mvn clean install -DskipTests

# Gradle
./gradlew clean build
./gradlew jar

# Direct compilation
javac -d out -cp "lib/*" src/main/java/com/example/*.java
jar cf myapp.jar -C out .
```

**Run**
```bash
# Single file (Java 11 feature)
java HelloWorld.java

# Maven
mvn exec:java -Dexec.mainClass="com.example.Main"

# Gradle
./gradlew run

# JAR execution
java -jar target/myapp.jar
java -cp "myapp.jar:lib/*" com.example.Main
```
