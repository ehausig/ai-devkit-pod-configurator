#### Java 17 (Eclipse Adoptium Temurin)

**Why Adoptium**: TCK tested, regular updates, drop-in Oracle JDK replacement

**Java 17 LTS Features**:
- Records: `record Person(String name, int age) {}`
- Pattern matching: `if (obj instanceof String s) { /* use s */ }`
- Text blocks: `"""multi-line"""`
- Sealed classes

**Testing**:
```java
@ParameterizedTest
@ValueSource(strings = {"hello", "world"})
void testWithParams(String value) {
    assertNotNull(value);
}
```

**Microservices**: Spring Boot 2.5+ has full Java 17 support

**Performance**: Use ZGC for low latency: `-XX:+UseZGC`
