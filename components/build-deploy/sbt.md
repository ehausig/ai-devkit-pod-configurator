#### SBT

**Environment Setup**
```bash
# SBT downloads dependencies automatically
sbt --version

# Configure JVM options
echo "-Xmx2G" >> .sbtopts
echo "-XX:+UseG1GC" >> .sbtopts
```

**Project Init**
```bash
# Create from template
sbt new scala/scala3.g8
sbt new playframework/play-scala-seed.g8

# Manual setup
mkdir -p src/{main,test}/{scala,resources}
echo 'scalaVersion := "3.3.1"' > build.sbt
```

**Dependencies**
```bash
# In build.sbt:
libraryDependencies ++= Seq(
  "org.typelevel" %% "cats-core" % "2.10.0",
  "org.scalatest" %% "scalatest" % "3.2.17" % Test
)

# Interactive mode
sbt
> reload  // Reload build definition
> update  // Fetch dependencies
> dependencyTree  // Show tree
```

**Format & Lint**
```bash
# Add to project/plugins.sbt:
addSbtPlugin("org.scalameta" % "sbt-scalafmt" % "2.5.2")

# Format code
sbt scalafmt

# Check formatting
sbt scalafmtCheck

# Format on compile
scalafmtOnCompile := true
```

**Testing**

*Unit Tests*
```bash
# Run unit tests only
sbt "testOnly *Test"
sbt "testOnly *Spec"

# Continuous testing
sbt ~test

# Quick test (only changed)
sbt testQuick

# Test specific package
sbt "testOnly com.example.unit.*"
```

*Integration Tests*
```bash
# Configure IntegrationTest in build.sbt
lazy val IntegrationTest = config("it") extend Test

lazy val root = project
  .configs(IntegrationTest)
  .settings(Defaults.itSettings)
  .settings(
    IntegrationTest / fork := true,
    IntegrationTest / parallelExecution := false
  )

# Run integration tests
sbt it:test

# Run specific integration test
sbt "it:testOnly *IntegrationSpec"
```

*User Simulation Tests*
```bash
# E2E test configuration
Test / testOptions += Tests.Argument("-l", "E2E")

# Run E2E tests
sbt "testOnly *E2E"

# With test tags
sbt "testOnly * -- -n E2E"

# All test levels in sequence
sbt clean compile test it:test "testOnly *E2E"
```

*Test Configuration*
```scala
// build.sbt test settings
Test / parallelExecution := true
Test / testOptions += Tests.Argument(TestFrameworks.ScalaTest, "-oD")
Test / logBuffered := false

// Coverage with sbt-scoverage
addSbtPlugin("org.scoverage" % "sbt-scoverage" % "2.0.9")

// Run with coverage
sbt clean coverage test coverageReport

// View coverage
open target/scala-2.13/scoverage-report/index.html
```

**Build**
```bash
# Compile
sbt compile

# Package JAR
sbt package

# Assembly (fat JAR) - requires plugin
sbt assembly

# Publish locally
sbt publishLocal

# Clean
sbt clean
```

**Run**
```bash
# Run main class
sbt run

# Run with arguments
sbt "run arg1 arg2"

# Continuous compilation & run
sbt ~run

# Interactive REPL
sbt console

# Run specific main
sbt "runMain com.example.Main"
```
