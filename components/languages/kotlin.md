#### Kotlin

**Quick Start**:
- REPL: `kotlinc`
- Run script: `kotlin script.kts`
- Compile: `kotlinc Hello.kt -include-runtime -d hello.jar`

**Features**:
- Null safety: `var name: String? = null`
- Data classes: `data class Person(val name: String)`
- Extension functions: `fun String.lastChar() = this[length - 1]`

**Testing**:
```kotlin
import kotlin.test.*

class MyTest {
    @Test
    fun testExample() {
        assertTrue { 1 + 1 == 2 }
    }
}
```

**Ktor API**:
```kotlin
embeddedServer(Netty, port = 8080) {
    routing {
        get("/") { call.respondText("Hello") }
    }
}.start(wait = true)
```

**Build**: Use Gradle for dependencies (see Gradle section)
