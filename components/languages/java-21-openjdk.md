#### Java 21 (OpenJDK LTS)

**Environment Setup**
```bash
# Java doesn't use virtual environments
java -version  # Verify Java 21
javac -version

# Set JAVA_HOME if needed
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
```

**Project Init**
```bash
# Maven project
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp \
  -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false

# Gradle project
gradle init --type java-application --dsl kotlin --java-version 21

# Simple structure
mkdir -p src/main/java/com/example src/test/java/com/example
```

**Dependencies**
```bash
# Maven (pom.xml) - use latest versions for Java 21
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
# Same as Java 17
# Google Java Format supports Java 21
java -jar google-java-format.jar --replace src/**/*.java

# Maven Spotless
mvn spotless:apply

# Gradle Spotless
./gradlew spotlessApply
```

**Testing**

*Unit Tests*
```bash
# Maven unit tests
mvn test -Dtest="*Test"

# Gradle unit tests
./gradlew test --tests "*Test"

# JUnit 5 with Java 21 features
// src/test/java/CalculatorTest.java
@Test
void testWithVirtualThreads() throws Exception {
    try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
        var futures = IntStream.range(0, 1000)
            .mapToObj(i -> executor.submit(() -> calculate(i)))
            .toList();
        
        var results = futures.stream()
            .map(Future::join)
            .toList();
            
        assertEquals(1000, results.size());
    }
}

// Pattern matching in tests
@Test
void testPatternMatching() {
    Object obj = "Hello";
    
    switch (obj) {
        case String s when s.length() > 0 -> assertEquals("Hello", s);
        case null -> fail("Should not be null");
        default -> fail("Unexpected type");
    }
}
```

*Integration Tests*
```bash
# Spring Boot integration with virtual threads
// src/test/java/UserControllerIT.java
@SpringBootTest(properties = {
    "spring.threads.virtual.enabled=true"
})
@AutoConfigureMockMvc
class UserControllerIT {
    @Autowired
    private MockMvc mockMvc;
    
    @Test
    void testConcurrentRequests() throws Exception {
        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            var futures = IntStream.range(0, 100)
                .mapToObj(i -> executor.submit(() -> 
                    mockMvc.perform(get("/api/users/" + i))
                        .andExpect(status().isOk())
                ))
                .toList();
                
            futures.forEach(Future::join);
        }
    }
}

// TestContainers with Java 21
@Testcontainers
class DatabaseIT {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")
        .withDatabaseName("testdb");
        
    @Test
    void testWithRealDatabase() {
        var jdbcUrl = postgres.getJdbcUrl();
        // Test with actual PostgreSQL
    }
}
```

*User Simulation Tests*
```bash
# TUI testing
npx @microsoft/tui-test src/test/e2e/

# Playwright with Java
mvn test -Dtest="*E2E"

// src/test/java/LoginE2E.java
class LoginE2E {
    @Test
    void testCompleteUserFlow() {
        try (Playwright playwright = Playwright.create()) {
            Browser browser = playwright.chromium().launch();
            Page page = browser.newPage();
            
            page.navigate("http://localhost:8080");
            page.fill("input[name='email']", "user@example.com");
            page.fill("input[name='password']", "password");
            page.click("button[type='submit']");
            
            assertThat(page).hasURL("http://localhost:8080/dashboard");
            page.screenshot(new Page.ScreenshotOptions()
                .setPath(Paths.get("screenshots/dashboard.png")));
                
            browser.close();
        }
    }
}

# Performance testing with virtual threads
@Test
void loadTestWithVirtualThreads() throws Exception {
    var executor = Executors.newVirtualThreadPerTaskExecutor();
    var latch = new CountDownLatch(10_000);
    
    var start = System.nanoTime();
    for (int i = 0; i < 10_000; i++) {
        executor.submit(() -> {
            makeHttpRequest();
            latch.countDown();
        });
    }
    
    latch.await();
    var duration = Duration.ofNanos(System.nanoTime() - start);
    
    assertTrue(duration.toSeconds() < 5, "Should handle 10k requests in under 5 seconds");
}
```

**Build**
```bash
# Enable preview features if needed
# Maven
mvn clean package -DcompilerArgs="--enable-preview"

# Gradle
tasks.withType<JavaCompile> {
    options.compilerArgs.add("--enable-preview")
}

# Standard build
mvn clean package
./gradlew build
```

**Run**
```bash
# Run with virtual threads
java --enable-preview -jar myapp.jar

# Simple HTTP server with virtual threads
var server = HttpServer.create(new InetSocketAddress(8080), 0);
server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
server.start();

# Standard run commands
mvn exec:java
./gradlew run
```
