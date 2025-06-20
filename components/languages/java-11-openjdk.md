#### Java 11 (OpenJDK)

**Java 11 Features**:
- Local var inference: `var list = new ArrayList<String>();`
- HTTP Client API: Built-in `java.net.http`
- Single-file: `java HelloWorld.java` (no javac needed)
- String methods: `isBlank()`, `lines()`, `repeat(n)`

**HTTP Client**:
```java
var client = HttpClient.newHttpClient();
var request = HttpRequest.newBuilder()
    .uri(URI.create("https://api.example.com"))
    .build();
var response = client.send(request, HttpResponse.BodyHandlers.ofString());
```

**Testing**: Use JUnit 5 with Maven/Gradle

**Note**: LTS support ends 2026. Consider Java 17/21 for new projects.
