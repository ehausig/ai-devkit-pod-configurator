#### Java 11 (Eclipse Adoptium Temurin)

**Environment Setup**
```bash
# Verify Adoptium Java 11
java -version  # Should show "Temurin"
javac -version

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/temurin-11
```

**Project Init**
```bash
# Same as OpenJDK Java 11
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp \
  -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false

# Spring Boot 2.x project
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp \
  -DarchetypeArtifactId=spring-boot-maven-archetype
```

**Dependencies**
```bash
# Maven - optimized for Temurin
<properties>
    <maven.compiler.source>11</maven.compiler.source>
    <maven.compiler.target>11</maven.compiler.target>
</properties>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>2.7.18</version>
</dependency>
```

**Format & Lint**
```bash
# Same tools as OpenJDK
# Spotless Maven plugin
mvn spotless:apply
mvn spotless:check

# PMD for code analysis
mvn pmd:check
```

**Testing**

*Unit Tests*
```bash
# Run unit tests
mvn test -Dtest="*Test"
./gradlew test --tests "*Test"

# JUnit 5 with Java 11
// src/test/java/CalculatorTest.java
@Test
void testBasicCalculation() {
    var calculator = new Calculator();  // Java 11 var
    assertEquals(5, calculator.add(2, 3));
}

// HTTP Client unit test
@Test
void testHttpClientMock() {
    var client = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build();
        
    // Mock the response
    var request = HttpRequest.newBuilder()
        .uri(URI.create("http://mock.test/api"))
        .build();
        
    assertNotNull(client);
    assertNotNull(request);
}
```

*Integration Tests*
```bash
# Spring Boot 2.x integration tests
mvn verify -Dit.test="*IT"

// src/test/java/UserServiceIT.java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
class UserServiceIT {
    @Autowired
    private MockMvc mockMvc;
    
    @Test
    void testCreateUserEndpoint() throws Exception {
        var userJson = """
            {
                "email": "test@example.com",
                "name": "Test User"
            }
            """.strip();  // Java 11 text blocks preview
            
        mockMvc.perform(post("/api/users")
            .contentType(MediaType.APPLICATION_JSON)
            .content(userJson))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").isNumber());
    }
}

// Database integration with H2
@DataJpaTest
class RepositoryIT {
    @Autowired
    private UserRepository userRepository;
    
    @Test
    void testSaveAndFind() {
        var user = new User("test@example.com");
        var saved = userRepository.save(user);
        
        assertNotNull(saved.getId());
        assertTrue(userRepository.findByEmail("test@example.com").isPresent());
    }
}
```

*User Simulation Tests*
```bash
# TUI testing
npx @microsoft/tui-test src/test/e2e/

# Selenium WebDriver tests
mvn test -Dtest="*E2E" -DargLine="-XX:+UseG1GC -XX:+UseStringDeduplication"

// src/test/java/LoginFlowE2E.java
@Test
void testCompleteUserJourney() {
    // Adoptium optimizations for Selenium
    System.setProperty("webdriver.chrome.driver", "drivers/chromedriver");
    
    ChromeOptions options = new ChromeOptions();
    options.addArguments("--headless");  // For CI/CD
    
    WebDriver driver = new ChromeDriver(options);
    WebDriverWait wait = new WebDriverWait(driver, Duration.ofSeconds(10));
    
    try {
        driver.get("http://localhost:8080");
        
        // Login flow
        driver.findElement(By.id("email")).sendKeys("user@example.com");
        driver.findElement(By.id("password")).sendKeys("password");
        driver.findElement(By.id("login-btn")).click();
        
        // Wait for dashboard
        wait.until(ExpectedConditions.urlContains("/dashboard"));
        
        // Verify elements
        assertTrue(driver.findElement(By.tagName("h1"))
            .getText().contains("Dashboard"));
            
    } finally {
        driver.quit();
    }
}

// API smoke tests
@Test
void testApiAvailability() {
    var client = HttpClient.newHttpClient();
    var request = HttpRequest.newBuilder()
        .uri(URI.create("http://localhost:8080/api/health"))
        .timeout(Duration.ofSeconds(5))
        .build();
        
    var response = client.sendAsync(request, HttpResponse.BodyHandlers.ofString())
        .join();
        
    assertEquals(200, response.statusCode());
}
```

**Build**
```bash
# Optimized for Adoptium JVM
# Maven with G1GC
mvn clean package -DargLine="-XX:+UseG1GC"

# Gradle
./gradlew build

# Enable string deduplication
java -XX:+UseStringDeduplication -jar myapp.jar
```

**Run**
```bash
# Production optimizations for Adoptium
java -XX:+UseG1GC -XX:+UseStringDeduplication -jar myapp.jar

# HTTP client example
var client = HttpClient.newBuilder()
    .version(HttpClient.Version.HTTP_2)
    .connectTimeout(Duration.ofSeconds(10))
    .build();

# Standard execution
mvn exec:java
./gradlew run
```
