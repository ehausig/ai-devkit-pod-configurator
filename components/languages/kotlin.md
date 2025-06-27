#### Kotlin

**Environment Setup**
```bash
# Kotlin uses Gradle/Maven, no virtual env needed
kotlin -version
kotlinc -version

# Install Kotlin if needed
sdk install kotlin  # Using SDKMAN
```

**Project Init**
```bash
# Gradle project (recommended)
gradle init --type kotlin-application --dsl kotlin

# Manual structure
mkdir -p src/main/kotlin src/test/kotlin
touch build.gradle.kts

# Basic build.gradle.kts
echo 'plugins {
    kotlin("jvm") version "1.9.22"
    application
}' > build.gradle.kts
```

**Dependencies**
```bash
# In build.gradle.kts:
dependencies {
    implementation("io.ktor:ktor-server-netty:2.3.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    testImplementation(kotlin("test"))
}

# Refresh dependencies
./gradlew build --refresh-dependencies
```

**Format & Lint**
```bash
# Ktlint via Gradle plugin
# Add to build.gradle.kts:
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.0.3"
}

# Format code
./gradlew ktlintFormat

# Check format
./gradlew ktlintCheck
```

**Testing**

*Unit Tests*
```bash
# Run unit tests
./gradlew test --tests "*Test"

# Run specific test class
./gradlew test --tests "com.example.CalculatorTest"

# Kotlin test examples
// src/test/kotlin/CalculatorTest.kt
import kotlin.test.*

class CalculatorTest {
    @Test
    fun `should add two numbers`() {
        assertEquals(5, Calculator.add(2, 3))
    }
    
    @ParameterizedTest
    @ValueSource(ints = [1, 2, 3])
    fun `should be positive`(number: Int) {
        assertTrue(number > 0)
    }
}

# Using Kotest (BDD style)
class CalculatorSpec : StringSpec({
    "add should return sum of two numbers" {
        Calculator.add(2, 3) shouldBe 5
    }
})
```

*Integration Tests*
```bash
# Run integration tests
./gradlew integrationTest

# Ktor API testing
// src/test/kotlin/ApiIntegrationTest.kt
class ApiIntegrationTest {
    @Test
    fun `test API endpoint`() = testApplication {
        application {
            configureRouting()
        }
        client.get("/api/users").apply {
            assertEquals(HttpStatusCode.OK, status)
            assertEquals("application/json", contentType()
        }
    }
}

# Database integration with Exposed
@Test
fun `test user creation`() = runBlocking {
    Database.connect("jdbc:h2:mem:test")
    transaction {
        val userId = Users.insertAndGetId {
            it[email] = "test@example.com"
        }
        assertNotNull(userId)
    }
}
```

*User Simulation Tests*
```bash
# TUI testing with Microsoft TUI Test
npx @microsoft/tui-test src/test/e2e/

# Selenium with Kotlin
./gradlew e2eTest

# Example: Selenide test
// src/test/kotlin/LoginE2ETest.kt
import com.codeborne.selenide.Selenide.*
import com.codeborne.selenide.Condition.*

class LoginE2ETest {
    @Test
    fun `user can log in`() {
        open("http://localhost:8080")
        `#### Kotlin

**Environment Setup**
```bash
# Kotlin uses Gradle/Maven, no virtual env needed
kotlin -version
kotlinc -version

# Install Kotlin if needed
sdk install kotlin  # Using SDKMAN
```

**Project Init**
```bash
# Gradle project (recommended)
gradle init --type kotlin-application --dsl kotlin

# Manual structure
mkdir -p src/main/kotlin src/test/kotlin
touch build.gradle.kts

# Basic build.gradle.kts
echo 'plugins {
    kotlin("jvm") version "1.9.22"
    application
}' > build.gradle.kts
```

**Dependencies**
```bash
# In build.gradle.kts:
dependencies {
    implementation("io.ktor:ktor-server-netty:2.3.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    testImplementation(kotlin("test"))
}

# Refresh dependencies
./gradlew build --refresh-dependencies
```

**Format & Lint**
```bash
# Ktlint via Gradle plugin
# Add to build.gradle.kts:
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.0.3"
}

# Format code
./gradlew ktlintFormat

# Check format
./gradlew ktlintCheck
```

("[name=email]").setValue("user@example.com")
        `#### Kotlin

**Environment Setup**
```bash
# Kotlin uses Gradle/Maven, no virtual env needed
kotlin -version
kotlinc -version

# Install Kotlin if needed
sdk install kotlin  # Using SDKMAN
```

**Project Init**
```bash
# Gradle project (recommended)
gradle init --type kotlin-application --dsl kotlin

# Manual structure
mkdir -p src/main/kotlin src/test/kotlin
touch build.gradle.kts

# Basic build.gradle.kts
echo 'plugins {
    kotlin("jvm") version "1.9.22"
    application
}' > build.gradle.kts
```

**Dependencies**
```bash
# In build.gradle.kts:
dependencies {
    implementation("io.ktor:ktor-server-netty:2.3.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    testImplementation(kotlin("test"))
}

# Refresh dependencies
./gradlew build --refresh-dependencies
```

**Format & Lint**
```bash
# Ktlint via Gradle plugin
# Add to build.gradle.kts:
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.0.3"
}

# Format code
./gradlew ktlintFormat

# Check format
./gradlew ktlintCheck
```

("[name=password]").setValue("password")
        `#### Kotlin

**Environment Setup**
```bash
# Kotlin uses Gradle/Maven, no virtual env needed
kotlin -version
kotlinc -version

# Install Kotlin if needed
sdk install kotlin  # Using SDKMAN
```

**Project Init**
```bash
# Gradle project (recommended)
gradle init --type kotlin-application --dsl kotlin

# Manual structure
mkdir -p src/main/kotlin src/test/kotlin
touch build.gradle.kts

# Basic build.gradle.kts
echo 'plugins {
    kotlin("jvm") version "1.9.22"
    application
}' > build.gradle.kts
```

**Dependencies**
```bash
# In build.gradle.kts:
dependencies {
    implementation("io.ktor:ktor-server-netty:2.3.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    testImplementation(kotlin("test"))
}

# Refresh dependencies
./gradlew build --refresh-dependencies
```

**Format & Lint**
```bash
# Ktlint via Gradle plugin
# Add to build.gradle.kts:
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.0.3"
}

# Format code
./gradlew ktlintFormat

# Check format
./gradlew ktlintCheck
```

("button[type=submit]").click()
        
        `#### Kotlin

**Environment Setup**
```bash
# Kotlin uses Gradle/Maven, no virtual env needed
kotlin -version
kotlinc -version

# Install Kotlin if needed
sdk install kotlin  # Using SDKMAN
```

**Project Init**
```bash
# Gradle project (recommended)
gradle init --type kotlin-application --dsl kotlin

# Manual structure
mkdir -p src/main/kotlin src/test/kotlin
touch build.gradle.kts

# Basic build.gradle.kts
echo 'plugins {
    kotlin("jvm") version "1.9.22"
    application
}' > build.gradle.kts
```

**Dependencies**
```bash
# In build.gradle.kts:
dependencies {
    implementation("io.ktor:ktor-server-netty:2.3.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    testImplementation(kotlin("test"))
}

# Refresh dependencies
./gradlew build --refresh-dependencies
```

**Format & Lint**
```bash
# Ktlint via Gradle plugin
# Add to build.gradle.kts:
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.0.3"
}

# Format code
./gradlew ktlintFormat

# Check format
./gradlew ktlintCheck
```

("h1").shouldHave(text("Dashboard"))
        webdriver().shouldHave(url("http://localhost:8080/dashboard"))
    }
}
```

**Build**
```bash
# Build project
./gradlew build

# Create JAR
./gradlew jar

# Create fat JAR
./gradlew shadowJar  # Requires shadow plugin

# Clean build
./gradlew clean build
```

**Run**
```bash
# Run application
./gradlew run

# Run Kotlin script
kotlin script.kts

# Compile and run manually
kotlinc hello.kt -include-runtime -d hello.jar
java -jar hello.jar

# REPL
kotlinc
```
