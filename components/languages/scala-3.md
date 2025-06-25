#### Scala 3

**New Syntax**:
- Optional braces, `then` keyword
- Union types: `String | Int`
- Extension methods: `extension (x: Int) def twice = x * 2`
- Enums: `enum Color { case Red, Green, Blue }`

**REPL**: `scala` or `scala3`

**Testing**:
```scala
// ScalaTest
class MySpec extends AnyFunSuite {
  test("addition") { assert(1 + 1 === 2) }
}

// MUnit (lightweight)
class MySuite extends munit.FunSuite {
  test("example") { assertEquals(obtained, expected) }
}
```

**Quick Start**: Top-level definitions, given instances, export clauses

**Build**: Use SBT (see SBT section)
