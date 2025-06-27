#### Java 21 (Eclipse Adoptium Temurin LTS)

**Environment Setup**
```bash
# Verify Adoptium Java 21
java -version  # Should show "Temurin"
javac -version

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/temurin-21
```

**Project Init**
```bash
# Latest Spring Boot with Java 21
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp \
  -DarchetypeArtifactId=spring-boot-starter-parent \
  -DarchetypeVersion=3.2.0

# Gradle with Java 21
gradle init --type java-application --dsl kotlin \
  --java-version 21 --project-name myapp
```

**Dependencies**
```bash
# Maven - Java 21 with virtual threads
<properties>
    <java.version>21</java.version>
</properties>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>3.2.0</version>
</dependency>

# Enable virtual threads in Spring Boot
spring.threads.virtual.enabled=true
```

**Format & Lint**
```bash
# Same as Java 17/21
mvn spotless:apply

# Google Java Format with Java 21
java -jar google-java-format.jar --aosp src/**/*.java

# Modern linting
./gradlew spotlessApply
```

**Testing**

*Unit Tests*
```bash
# Run unit tests with virtual threads
mvn test -Dtest="*Test"

# JUnit 5 with Java 21 and virtual threads
// src/test/java/CalculatorTest.java
@Test
void testWithVirtualThreads() throws Exception {
    try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
        var futures = IntStream.range(0, 10_000)
            .mapToObj(i -> executor.submit(() -> calculate(i)))
            .toList();
        
        // All 10k tasks run on virtual threads
        var results = futures.stream()
            .map(Future::join)
            .toList();
            
        assertEquals(10_000, results.size());
        assertTrue(results.stream().allMatch(r -> r > 0));
    }
}

// Pattern matching with switch
@Test
void testPatternMatching() {
    Object result = processInput("test");
    
    var message = switch (result) {
        case String s when s.length() > 0 -> "Valid string: " + s;
        case Integer i -> "Number: " + i;
        case null -> "Null input";
        default -> "Unknown type";
    };
    
    assertEquals("Valid string: test", message);
}
```

*Integration Tests*
```bash
# Spring Boot with virtual threads enabled
mvn verify -Dit.test="*IT" -Dspring.threads.virtual.enabled=true

// src/test/java/ApiIntegrationIT.java
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "spring.threads.virtual.enabled=true"
)
class ApiIntegrationIT {
    @Autowired
    private TestRestTemplate restTemplate;
    
    @Test
    void testConcurrentApiCalls() throws Exception {
        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            // Test 1000 concurrent API calls
            var futures = IntStream.range(0, 1000)
                .mapToObj(i -> executor.submit(() -> 
                    restTemplate.getForObject("/api/data/" + i, String.class)
                ))
                .toList();
                
            var responses = futures.stream()
                .map(Future::join)
                .toList();
                
            assertEquals(1000, responses.size());
        }
    }
}

// TestContainers with Java 21
@Test
void testWithMultipleContainers() {
    try (
        var postgres = new PostgreSQLContainer<>("postgres:16");
        var redis = new GenericContainer<>("redis:7-alpine")
    ) {
        postgres.start();
        redis.start();
        
        // Test with both containers
        // Adoptium JVM handles container resources efficiently
    }
}
```

*User Simulation Tests*
```bash
# E2E tests with virtual threads
mvn test -Dtest="*E2E"

// src/test/java/LoadTestE2E.java
@Test
void testHighConcurrencyUserFlow() throws Exception {
    var executor = Executors.newVirtualThreadPerTaskExecutor();
    var successCount = new AtomicInteger(0);
    
    // Simulate 10,000 concurrent users
    var futures = IntStream.range(0, 10_000)
        .mapToObj(userId -> executor.submit(() -> {
            try (var playwright = Playwright.create()) {
                var browser = playwright.chromium().launch(
                    new BrowserType.LaunchOptions().setHeadless(true)
                );
                var page = browser.newPage();
                
                page.navigate("http://localhost:8080");
                page.fill("[name='email']", "user" + userId + "@example.com");
                page.fill("[name='password']", "password");
                page.click("button[type='submit']");
                
                if (page.url().contains("/dashboard")) {
                    successCount.incrementAndGet();
                }
                
                browser.close();
            }
        }))
        .toList();
    
    // Wait for all virtual threads to complete
    futures.forEach(Future::join);
    
    // Adoptium with ZGC should handle this load efficiently
    assertTrue(successCount.get() > 9900, "At least 99% success rate");
}

// TUI testing
npx @microsoft/tui-test src/test/e2e/
```

**Build**
```bash
# Standard build
mvn clean package

# With preview features
mvn clean package -DcompilerArgs="--enable-preview"

# Optimized for production
./gradlew build -Dorg.gradle.jvmargs="-XX:+UseZGC"
```

**Run**
```bash
# Run with virtual threads
java -jar myapp.jar

# With ZGC for low latency
java -XX:+UseZGC -jar myapp.jar

# Simple HTTP server with virtual threads
var executor = Executors.newVirtualThreadPerTaskExecutor();
server.setExecutor(executor);

# Spring Boot with virtual threads
mvn spring-boot:run -Dspring.threads.virtual.enabled=true
```
