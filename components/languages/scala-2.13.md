#### Scala 2.13

**REPL**: `scala` → Run scripts: `scala script.scala`

**Testing**:
```scala
// ScalaTest
class MySpec extends AnyFlatSpec with Matchers {
  "Stack" should "pop values in LIFO order" in {
    stack.pop() should be (2)
  }
}
```

**Common Libraries**:
- Cats: `"org.typelevel" %% "cats-core" % "2.10.0"`
- Akka HTTP: `"com.typesafe.akka" %% "akka-http" % "10.5.0"`
- Http4s: `"org.http4s" %% "http4s-dsl" % "0.23.23"`

**Key Points**:
- Use `%%` for Scala libs (cross-compilation)
- Binary compatibility matters (2.13 ≠ 2.12)
- Test continuously: `sbt ~test`

**Build**: Use SBT for dependency management
