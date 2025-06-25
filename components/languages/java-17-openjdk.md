#### Java 17 (OpenJDK)

**Java 17 Features**:
- Text blocks: `"""multi-line strings"""`
- Records: `record Point(int x, int y) {}`
- Pattern matching: `if (obj instanceof String s) { use s }`
- Sealed classes: `sealed class Shape permits Circle, Rectangle`

**Quick Run**: `java MyProgram.java` (single-file programs)

**Spring Boot**:
```java
@RestController
public class ApiController {
    @GetMapping("/status")
    public Map<String, String> status() {
        return Map.of("status", "running", "java", "17");
    }
}
```

**Testing**: JUnit 5, AssertJ, TestContainers, MockWebServer

**Performance**: G1GC default, records reduce boilerplate
