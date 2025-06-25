#### Java 21 (Eclipse Adoptium Temurin LTS)

**Virtual Threads** (game changer):
```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    IntStream.range(0, 10_000).forEach(i -> 
        executor.submit(() -> processRequest(i))
    );
}
```

**Modern API**:
```java
var server = HttpServer.create(new InetSocketAddress(8080), 0);
server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
server.createContext("/api", this::handleRequest);
server.start();
```

**Testing**: Test with thousands of virtual threads

**Performance**:
- Low latency: `-XX:+UseZGC`
- Default G1GC for balance
- Profile with JFR

**Migration**: Virtual threads are drop-in replacements, no pooling needed
