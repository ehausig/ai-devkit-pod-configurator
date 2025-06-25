#### Java 11 (Eclipse Adoptium Temurin)

**Why Adoptium**: Production-ready, TCK-tested, regular updates

**HTTP Client (Java 11)**:
```java
var client = HttpClient.newBuilder()
    .connectTimeout(Duration.ofSeconds(10))
    .build();
    
client.sendAsync(request, HttpResponse.BodyHandlers.ofString())
    .thenApply(HttpResponse::body)
    .thenAccept(System.out::println);
```

**Testing**: JUnit 4/5, Mockito, AssertJ, Spring Boot Test

**Enterprise**: Spring Boot 2.x, older apps often require Java 11

**Performance**: G1GC default, use `-XX:+UseStringDeduplication`
