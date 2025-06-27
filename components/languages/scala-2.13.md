#### Scala 2.13

**Environment Setup**
```bash
# Scala uses SBT, no virtual env needed
scala -version

# Install via Coursier
cs setup
cs install scala:2.13.12 scalac:2.13.12
```

**Project Init**
```bash
# SBT template
sbt new scala/scala-seed.g8

# Manual setup
mkdir -p src/{main,test}/scala project
echo 'scalaVersion := "2.13.12"' > build.sbt
echo 'sbt.version=1.9.7' > project/build.properties
```

**Dependencies**
```bash
# In build.sbt (note %% for Scala versioning)
libraryDependencies ++= Seq(
  "org.typelevel" %% "cats-core" % "2.10.0",
  "com.typesafe.akka" %% "akka-actor-typed" % "2.8.5",
  "org.scalatest" %% "scalatest" % "3.2.17" % Test
)

# Update dependencies
sbt update
sbt dependencyTree
```

**Format & Lint**
```bash
# Scalafmt setup
echo 'version = "3.7.17"' > .scalafmt.conf

# Add to project/plugins.sbt
addSbtPlugin("org.scalameta" % "sbt-scalafmt" % "2.5.2")

# Format
sbt scalafmt
sbt test:scalafmt

# Wartremover for linting
addSbtPlugin("org.wartremover" % "sbt-wartremover" % "3.1.5")
```

**Testing**
```bash
# Run tests
sbt test

# Continuous testing
sbt ~test

# Specific test
sbt "testOnly com.example.MySpec"

# ScalaTest example
class MySpec extends AnyFlatSpec with Matchers {
  "A Stack" should "pop values in LIFO order" in {
    val stack = new Stack[Int]
    stack.push(1)
    stack.push(2)
    stack.pop() should be (2)
  }
}
```

**Build**
```bash
# Compile
sbt compile

# Package JAR
sbt package

# Assembly (fat JAR)
sbt assembly

# Clean
sbt clean

# Stage for deployment
sbt stage
```

**Run**
```bash
# Run main class
sbt run

# Run with arguments
sbt "run arg1 arg2"

# REPL with project classpath
sbt console

# Quick REPL
scala

# Run specific main
sbt "runMain com.example.Main"
```
