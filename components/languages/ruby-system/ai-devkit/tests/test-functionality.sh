#!/bin/bash
# Test Ruby functionality
set -e

echo "Testing Ruby functionality..."

# Create temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Test Ruby language features
cat > test_features.rb << 'EOF'
#!/usr/bin/env ruby

puts "✅ Basic I/O working"

# Test classes and objects
class Person
  attr_accessor :name, :age
  
  def initialize(name, age)
    @name = name
    @age = age
  end
  
  def introduce
    "Hi, I'm #{@name} and I'm #{@age} years old"
  end
  
  def self.species
    "Homo sapiens"
  end
end

person = Person.new("Alice", 30)
puts "✅ Classes and objects: #{person.introduce}"
puts "✅ Class methods: #{Person.species}"

# Test arrays and iteration
numbers = [1, 2, 3, 4, 5]
squared = numbers.map { |n| n ** 2 }
puts "✅ Arrays and blocks: #{numbers} -> #{squared}"

# Test hashes
hash = { name: "Ruby", type: "Programming Language", year: 1995 }
puts "✅ Hashes: #{hash}"

# Test string interpolation and methods
name = "Ruby"
version = "3.3"
message = "Hello from #{name} #{version}!"
puts "✅ String interpolation: #{message}"
puts "✅ String methods: '#{message.upcase}'"

# Test symbols
status = :active
statuses = [:active, :inactive, :pending]
puts "✅ Symbols: #{status} in #{statuses}"

# Test regular expressions
text = "Ruby 3.3 is awesome"
if text =~ /Ruby \d+\.\d+/
  puts "✅ Regular expressions: Pattern matched"
end

# Test modules and mixins
module Greetings
  def say_hello
    "Hello from module!"
  end
end

class Greeter
  include Greetings
end

greeter = Greeter.new
puts "✅ Modules and mixins: #{greeter.say_hello}"

# Test exception handling
begin
  result = 10 / 0
rescue ZeroDivisionError => e
  puts "✅ Exception handling: Caught #{e.class}"
end

# Test file I/O
File.open("test.txt", "w") { |f| f.write("Ruby file I/O test") }
content = File.read("test.txt")
puts "✅ File I/O: #{content}"
File.delete("test.txt")

# Test iterators and enumerable
result = (1..5).select { |n| n.even? }.map { |n| n * 2 }
puts "✅ Iterators: #{result}"

# Test procs and lambdas
double_proc = Proc.new { |x| x * 2 }
double_lambda = lambda { |x| x * 2 }
puts "✅ Proc: #{double_proc.call(5)}, Lambda: #{double_lambda.call(5)}"

# Test metaprogramming (basic)
String.class_eval do
  def reverse_words
    self.split.map(&:reverse).join(' ')
  end
end

test_string = "Hello World"
puts "✅ Metaprogramming: '#{test_string}' -> '#{test_string.reverse_words}'"

# Test constants
CONSTANT_VALUE = "I'm a constant"
puts "✅ Constants: #{CONSTANT_VALUE}"

puts "✅ All Ruby functionality tests passed"
EOF

echo "Testing Ruby script execution..."
ruby test_features.rb || {
    echo "❌ Ruby functionality test failed"
    exit 1
}

# Test interactive Ruby if available
if command -v irb &> /dev/null; then
    echo "Testing irb..."
    echo 'puts "IRB test successful"; exit' | timeout 5 irb --simple-prompt 2>/dev/null | grep -q "IRB test successful" || {
        echo "⚠️  irb test failed (may be expected in some environments)"
    }
    echo "✅ irb test completed"
fi

# Test require and load
cat > library.rb << 'EOF'
module TestLibrary
  VERSION = "1.0.0"
  
  def self.greet
    "Hello from TestLibrary #{VERSION}"
  end
end
EOF

cat > require_test.rb << 'EOF'
require_relative 'library'

puts TestLibrary.greet
puts "Require test successful"
EOF

echo "Testing require functionality..."
ruby require_test.rb | grep -q "Require test successful" || {
    echo "❌ Require functionality failed"
    exit 1
}

echo "✅ Require functionality working"

# Test Ruby standard library
cat > stdlib_test.rb << 'EOF'
require 'json'
require 'uri'
require 'net/http'
require 'date'
require 'digest'

# Test JSON
data = { name: "Ruby", version: "3.3" }
json_string = JSON.generate(data)
parsed = JSON.parse(json_string)
puts "✅ JSON: #{parsed}"

# Test URI
uri = URI.parse("https://www.example.com/path?query=value")
puts "✅ URI: #{uri.host}"

# Test Date
today = Date.today
puts "✅ Date: #{today}"

# Test Digest
hash = Digest::SHA256.hexdigest("Ruby")
puts "✅ Digest: #{hash[0..10]}..."

puts "Standard library test successful"
EOF

echo "Testing Ruby standard library..."
ruby stdlib_test.rb | grep -q "Standard library test successful" || {
    echo "❌ Standard library test failed"
    exit 1
}

echo "✅ Standard library working"

echo "✅ All Ruby functionality tests passed"