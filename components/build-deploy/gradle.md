#### Gradle 8.5

**Quick Start**: `gradle init --type java-application` (interactive setup)

**Common Tasks**:
- `gradle build` - Compile, test, and package
- `gradle test` - Run tests only
- `gradle run` - Execute application
- `gradle tasks` - List available tasks

**Testing**:
- Continuous: `gradle test --continuous`
- Specific: `gradle test --tests "com.example.TestClass"`
- Reports in `build/reports/tests/`

**Kotlin DSL (build.gradle.kts)**:
```kotlin
plugins {
    kotlin("jvm") version "1.9.22"
    application
}
dependencies {
    testImplementation(kotlin("test"))
}
```

**Performance**:
- Daemon: `gradle --daemon` (default)
- Parallel: `gradle build --parallel`
- Debug: `gradle build --info`

**Wrapper**: Always use `./gradlew` for version consistency

**Dependencies**: `gradle dependencies` to view tree
