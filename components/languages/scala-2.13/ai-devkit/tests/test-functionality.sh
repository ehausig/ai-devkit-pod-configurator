#!/bin/bash
# Test Scala functionality
set -e

echo "Testing Scala functionality..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test Scala language features
cat > ScalaFeatures.scala << 'EOF'
import scala.collection.mutable
import scala.util.{Try, Success, Failure}
import scala.concurrent.Future
import scala.concurrent.ExecutionContext.Implicits.global
import java.io.{File, PrintWriter}

object ScalaFeatures {
  def main(args: Array[String]): Unit = {
    println("✅ Basic I/O working")
    
    // Test case classes and pattern matching
    case class Person(name: String, age: Int)
    val person = Person("Alice", 30)
    
    person match {
      case Person(name, age) if age >= 18 => 
        println(s"✅ Pattern matching: $name is an adult ($age)")
      case _ => 
        println("❌ Pattern matching failed")
    }
    
    // Test collections and higher-order functions
    val numbers = List(1, 2, 3, 4, 5)
    val doubled = numbers.map(_ * 2)
    val evens = numbers.filter(_ % 2 == 0)
    val sum = numbers.reduce(_ + _)
    
    println(s"✅ Collections: doubled=$doubled, evens=$evens, sum=$sum")
    
    // Test for-comprehensions
    val result = for {
      x <- List(1, 2, 3)
      y <- List(10, 20, 30)
      if x * y > 20
    } yield x * y
    
    println(s"✅ For-comprehensions: $result")
    
    // Test Option type
    val someValue: Option[Int] = Some(42)
    val noneValue: Option[Int] = None
    
    val mappedValue = someValue.map(_ * 2)
    println(s"✅ Option type: Some(42) -> $mappedValue")
    
    // Test Try for error handling
    val tryDivision = Try(10 / 2)
    tryDivision match {
      case Success(value) => println(s"✅ Try success: $value")
      case Failure(exception) => println(s"❌ Try failed: $exception")
    }
    
    // Test tuples
    val tuple = ("Scala", 2.13, true)
    println(s"✅ Tuples: ${tuple._1} version ${tuple._2}, awesome: ${tuple._3}")
    
    // Test traits and mixins
    trait Greeting {
      def greet: String = "Hello"
    }
    
    trait Farewell {
      def farewell: String = "Goodbye"
    }
    
    class Polite extends Greeting with Farewell {
      def politeGreet: String = s"$greet and $farewell"
    }
    
    val polite = new Polite
    println(s"✅ Traits and mixins: ${polite.politeGreet}")
    
    // Test anonymous functions
    val multiply = (x: Int, y: Int) => x * y
    println(s"✅ Anonymous functions: multiply(3, 4) = ${multiply(3, 4)}")
    
    // Test partial functions
    val divide: PartialFunction[(Int, Int), Int] = {
      case (x, y) if y != 0 => x / y
    }
    
    if (divide.isDefinedAt((10, 2))) {
      println(s"✅ Partial functions: 10/2 = ${divide((10, 2))}")
    }
    
    // Test mutable collections
    val mutableSet = mutable.Set[String]()
    mutableSet += "Scala"
    mutableSet += "Java"
    println(s"✅ Mutable collections: $mutableSet")
    
    // Test string interpolation
    val language = "Scala"
    val version = "2.13"
    println(s"✅ String interpolation: Welcome to $language $version!")
    println(f"✅ String formatting: Pi is approximately ${math.Pi}%.2f")
    
    // Test implicit parameters (simple example)
    implicit val multiplier: Int = 2
    def multiplyImplicitly(x: Int)(implicit m: Int): Int = x * m
    println(s"✅ Implicit parameters: 5 * 2 = ${multiplyImplicitly(5)}")
    
    // Test file I/O
    val writer = new PrintWriter(new File("test.txt"))
    writer.write("Scala file I/O test")
    writer.close()
    
    val source = scala.io.Source.fromFile("test.txt")
    val content = try source.mkString finally source.close()
    println(s"✅ File I/O: $content")
    new File("test.txt").delete()
    
    // Test class hierarchy
    abstract class Animal {
      def makeSound: String
    }
    
    class Dog extends Animal {
      override def makeSound: String = "Woof!"
    }
    
    val dog = new Dog
    println(s"✅ Class hierarchy: Dog says ${dog.makeSound}")
    
    // Test sealed traits (algebraic data types)
    sealed trait Shape
    case class Circle(radius: Double) extends Shape
    case class Rectangle(width: Double, height: Double) extends Shape
    
    def calculateArea(shape: Shape): Double = shape match {
      case Circle(r) => math.Pi * r * r
      case Rectangle(w, h) => w * h
    }
    
    val circle = Circle(5.0)
    println(f"✅ Sealed traits: Circle area = ${calculateArea(circle)}%.2f")
    
    println("✅ All Scala functionality tests passed")
  }
}
EOF

# Test compilation
echo "Testing Scala compilation..."
scalac ScalaFeatures.scala || {
    echo "❌ Failed to compile Scala functionality test"
    exit 1
}

echo "✅ Scala compilation working"

# Test execution
echo "Testing Scala execution..."
scala ScalaFeatures || {
    echo "❌ Failed to run Scala functionality test"
    exit 1
}

# Test Scala scripting
cat > script.scala << 'EOF'
#!/usr/bin/env scala

val message = "Hello from Scala script!"
println(message)

// Simple calculation
val numbers = (1 to 5).toList
val sum = numbers.sum
println(s"Sum of $numbers = $sum")

println("Scala script execution successful")
EOF

echo "Testing Scala script execution..."
scala script.scala | grep -q "Scala script execution successful" || {
    echo "❌ Scala script execution failed"
    exit 1
}

echo "✅ Scala script execution working"

echo "✅ All Scala functionality tests passed"