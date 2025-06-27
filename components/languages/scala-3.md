#### Scala 3

**Environment Setup**
```bash
# Scala uses SBT/Mill, no virtual env needed
scala -version

# Install via Coursier
cs setup
cs install scala3
```

**Project Init**
```bash
# SBT template
sbt new scala/scala3.g8

# Mill project
mill init com.example.myapp

# Manual SBT setup
mkdir -p src/main/scala src/test/scala
echo 'scalaVersion := "3.3.1"' > build.sbt
```

**Dependencies**
```bash
# In build.sbt:
libraryDependencies ++= Seq(
  "org.typelevel" %% "cats-core" % "2.10.0",
  "com.softwaremill.sttp.client3" %% "core" % "3.9.1",
  "org.scalameta" %% "munit" % "0.7.29" % Test
)

# Interactive SBT
sbt
> reload
> update
```

**Format & Lint**
```bash
# Scalafmt setup (project/.scalafmt.conf)
version = "3.7.17"
runner.dialect = scala3

# Format via SBT
sbt scalafmt

# Check formatting
sbt scalafmtCheck

# Scalafix for linting
sbt "scalafix RemoveUnused"
```

**Testing**

*Unit Tests*
```bash
# Run unit tests
sbt "testOnly *Spec"
sbt "testOnly *Test"

# Continuous testing
sbt ~test

# Example with MUnit
// src/test/scala/CalculatorTest.scala
class CalculatorTest extends munit.FunSuite {
  test("addition") {
    assertEquals(Calculator.add(2, 3), 5)
  }
  
  test("division by zero") {
    interceptMessage[ArithmeticException]("/ by zero") {
      Calculator.divide(10, 0)
    }
  }
}

# ScalaTest with FlatSpec
class CalculatorSpec extends AnyFlatSpec with Matchers {
  "Calculator" should "add two numbers correctly" in {
    Calculator.add(2, 3) shouldBe 5
  }
}
```

*Integration Tests*
```bash
# Separate integration test configuration
Test / testOptions += Tests.Argument("-l", "UnitTest")
IntegrationTest / testOptions := Seq.empty

# Run integration tests
sbt it:test

# Database integration with Slick
// src/it/scala/UserRepositorySpec.scala
class UserRepositorySpec extends AsyncFlatSpec with Matchers {
  "UserRepository" should "create and find users" in {
    val repo = new UserRepository(db)
    for {
      user <- repo.create("test@example.com")
      found <- repo.findByEmail("test@example.com")
    } yield {
      found shouldBe Some(user)
    }
  }
}

# HTTP API testing with sttp
test("API health check") {
  val request = basicRequest
    .get(uri"http://localhost:8080/health")
    
  val response = request.send(backend)
  assertEquals(response.code, StatusCode.Ok)
}
```

*User Simulation Tests*
```bash
# TUI testing with Microsoft TUI Test
npx @microsoft/tui-test src/test/e2e/

# Selenium with ScalaTest
sbt "testOnly *E2ESpec"

# Example browser test
// src/test/scala/LoginE2ESpec.scala
class LoginE2ESpec extends AnyFlatSpec with Matchers with WebBrowser {
  implicit val webDriver: WebDriver = new ChromeDriver()
  
  "User" should "be able to log in" in {
    go to "http://localhost:8080"
    emailField("email").value = "user@example.com"
    pwdField("password").value = "password"
    click on cssSelector("button[type='submit']")
    
    eventually {
      currentUrl shouldBe "http://localhost:8080/dashboard"
    }
  }
  
  override def afterAll(): Unit = {
    quit()
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

# Publish local
sbt publishLocal
```

**Run**
```bash
# Run main
sbt run

# Run with args
sbt "run arg1 arg2"

# REPL with project
sbt console

# Quick REPL
scala3

# Run script
scala3 script.scala
```
