#### SBT

**Quick Start**: `sbt new scala/scala3.g8` or `sbt new scala/hello-world.g8`

**Interactive Mode** (type `sbt`):
- `compile` - Compile sources
- `run` - Run main class
- `test` - Run tests
- `~test` - Watch mode (auto-rerun)
- `console` - Scala REPL with project

**Testing**:
- Specific test: `testOnly com.example.MySpec`
- Test quick: `testQuick` (only changed)
- Continuous: `~test`

**build.sbt**:
```scala
lazy val root = project.in(file("."))
  .settings(
    name := "myapp",
    scalaVersion := "3.3.1",
    libraryDependencies += "org.scalatest" %% "scalatest" % "3.2.17" % Test
  )
```

**Commands**: `clean`, `package`, `publishLocal`, `dependencyTree`

**Common Issues**: Binary compatibility → check Scala version alignment
