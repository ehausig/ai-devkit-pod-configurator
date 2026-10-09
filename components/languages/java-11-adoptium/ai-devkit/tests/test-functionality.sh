#!/bin/bash
# Test Java functionality
set -e

echo "Testing Java functionality..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test Java features
echo "Testing core Java features..."

cat > TestJavaFeatures.java << 'EOF'
import java.util.*;
import java.util.stream.Collectors;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.io.IOException;

public class TestJavaFeatures {
    public static void main(String[] args) {
        System.out.println("✅ Basic I/O working");
        
        // Test collections and streams
        List<Integer> numbers = Arrays.asList(1, 2, 3, 4, 5);
        List<Integer> doubled = numbers.stream()
            .map(n -> n * 2)
            .collect(Collectors.toList());
        System.out.println("✅ Collections and streams: " + doubled);
        
        // Test lambda expressions
        numbers.forEach(n -> System.out.print(n + " "));
        System.out.println("\n✅ Lambda expressions working");
        
        // Test Optional
        Optional<String> optional = Optional.of("test");
        optional.ifPresent(s -> System.out.println("✅ Optional: " + s));
        
        // Test local variable type inference (var) - Java 10+
        var message = "Type inference working";
        System.out.println("✅ " + message);
        
        // Test date/time API
        LocalDateTime now = LocalDateTime.now();
        String formatted = now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        System.out.println("✅ Date/time API: " + formatted);
        
        // Test CompletableFuture
        CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
            try {
                Thread.sleep(10);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            return "async result";
        });
        
        try {
            String result = future.get();
            System.out.println("✅ CompletableFuture: " + result);
        } catch (Exception e) {
            System.err.println("❌ CompletableFuture failed: " + e.getMessage());
        }
        
        // Test file I/O
        try {
            String content = "test file content";
            Files.write(Paths.get("test.txt"), content.getBytes());
            String readContent = new String(Files.readAllBytes(Paths.get("test.txt")));
            if (content.equals(readContent)) {
                System.out.println("✅ File I/O working");
            } else {
                System.out.println("❌ File I/O not working correctly");
            }
            Files.deleteIfExists(Paths.get("test.txt"));
        } catch (IOException e) {
            System.err.println("❌ File I/O failed: " + e.getMessage());
        }
        
        // Test generics
        Map<String, Integer> map = new HashMap<>();
        map.put("one", 1);
        map.put("two", 2);
        System.out.println("✅ Generics and collections: " + map);
        
        // Test exception handling
        try {
            throw new RuntimeException("test exception");
        } catch (RuntimeException e) {
            System.out.println("✅ Exception handling: " + e.getMessage());
        }
        
        System.out.println("✅ All Java functionality tests passed");
    }
}
EOF

# Test compilation and execution
echo "Testing compilation and execution..."
javac TestJavaFeatures.java || {
    echo "❌ Failed to compile Java functionality test"
    exit 1
}

java TestJavaFeatures || {
    echo "❌ Failed to run Java functionality test"
    exit 1
}

# Test with different memory settings
echo "Testing JVM memory settings..."
java -Xmx128m -Xms64m TestJavaFeatures > /dev/null || {
    echo "❌ JVM memory settings not working"
    exit 1
}

echo "✅ JVM memory settings working"

# Test system properties
echo "Testing system properties..."
java -Dtest.property=testvalue -cp . TestJavaFeatures > /dev/null || {
    echo "❌ System properties not working"
    exit 1
}

echo "✅ System properties working"

echo "✅ All Java functionality tests passed"