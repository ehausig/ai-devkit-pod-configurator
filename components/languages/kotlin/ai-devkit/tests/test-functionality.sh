#!/bin/bash
# Test Kotlin functionality
set -e

echo "Testing Kotlin functionality..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test Kotlin language features
cat > KotlinFeatures.kt << 'EOF'
import java.io.File

fun main() {
    println("✅ Basic I/O working")
    
    // Test data classes
    data class Person(val name: String, val age: Int)
    val person = Person("Alice", 30)
    println("✅ Data classes: $person")
    
    // Test when expression (pattern matching)
    val result = when (person.age) {
        in 0..17 -> "Minor"
        in 18..64 -> "Adult"
        else -> "Senior"
    }
    println("✅ When expressions: $result")
    
    // Test nullable types and safe calls
    val nullableString: String? = "Kotlin"
    val length = nullableString?.length ?: 0
    println("✅ Nullable types: length = $length")
    
    // Test collections and higher-order functions
    val numbers = listOf(1, 2, 3, 4, 5)
    val doubled = numbers.map { it * 2 }
    val evens = numbers.filter { it % 2 == 0 }
    val sum = numbers.sum()
    
    println("✅ Collections: doubled=$doubled, evens=$evens, sum=$sum")
    
    // Test lambda expressions
    val multiply = { x: Int, y: Int -> x * y }
    println("✅ Lambda expressions: multiply(3, 4) = ${multiply(3, 4)}")
    
    // Test extension functions
    fun String.wordCount(): Int = this.split(" ").size
    val text = "Hello Kotlin World"
    println("✅ Extension functions: '$text' has ${text.wordCount()} words")
    
    // Test sealed classes
    sealed class Result<out T>
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
    
    val apiResult: Result<String> = Success("API call successful")
    when (apiResult) {
        is Success -> println("✅ Sealed classes: ${apiResult.data}")
        is Error -> println("❌ Sealed classes: ${apiResult.message}")
    }
    
    // Test coroutines (basic)
    println("✅ Basic Kotlin features working (coroutines would need additional dependencies)")
    
    // Test string templates
    val language = "Kotlin"
    val version = "1.9"
    println("✅ String templates: Welcome to $language $version!")
    
    // Test ranges
    val range = 1..10
    val evenInRange = range.filter { it % 2 == 0 }
    println("✅ Ranges: even numbers in 1..10 = $evenInRange")
    
    // Test destructuring
    val (name, age) = person
    println("✅ Destructuring: name=$name, age=$age")
    
    // Test object declaration (singleton)
    object Utils {
        fun greet(name: String) = "Hello, $name!"
    }
    println("✅ Object declaration: ${Utils.greet("Kotlin")}")
    
    // Test companion object
    class Calculator {
        companion object {
            fun add(a: Int, b: Int) = a + b
        }
    }
    println("✅ Companion object: Calculator.add(2, 3) = ${Calculator.add(2, 3)}")
    
    // Test inline functions
    inline fun measureTime(action: () -> Unit): Long {
        val start = System.currentTimeMillis()
        action()
        return System.currentTimeMillis() - start
    }
    
    val time = measureTime {
        Thread.sleep(1)
    }
    println("✅ Inline functions: measured time = ${time}ms")
    
    // Test file I/O
    val file = File("test.txt")
    file.writeText("Kotlin file I/O test")
    val content = file.readText()
    println("✅ File I/O: $content")
    file.delete()
    
    // Test type aliases
    typealias StringList = List<String>
    val languages: StringList = listOf("Kotlin", "Java", "Scala")
    println("✅ Type aliases: $languages")
    
    println("✅ All Kotlin functionality tests passed")
}
EOF

# Test compilation
echo "Testing Kotlin compilation..."
kotlinc KotlinFeatures.kt -include-runtime -d KotlinFeatures.jar || {
    echo "❌ Failed to compile Kotlin functionality test"
    exit 1
}

echo "✅ Kotlin compilation working"

# Test execution
echo "Testing Kotlin execution..."
java -jar KotlinFeatures.jar || {
    echo "❌ Failed to run Kotlin functionality test"
    exit 1
}

echo "✅ All Kotlin functionality tests passed"