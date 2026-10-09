#!/bin/bash
# Test Java 21 Adoptium version
set -e

echo "Checking Java version..."

# Check if java command exists
if ! command -v java &> /dev/null; then
    echo "❌ java command not found"
    exit 1
fi

# Check if javac command exists
if ! command -v javac &> /dev/null; then
    echo "❌ javac command not found"
    exit 1
fi

# Check Java version
java_version=$(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}')
if [[ ! "$java_version" =~ ^21\. ]]; then
    echo "❌ Wrong Java version: $java_version (expected 21.x)"
    exit 1
fi

echo "✅ Java version: $java_version"

# Check if it's Adoptium/Eclipse Temurin
java_vendor=$(java -version 2>&1 | grep -i "eclipse\|adoptium\|temurin" || echo "")
if [[ -n "$java_vendor" ]]; then
    echo "✅ Adoptium/Eclipse Temurin detected"
else
    echo "⚠️  May not be Adoptium distribution"
fi

# Check javac version
javac_version=$(javac -version 2>&1 | awk '{print $2}')
echo "✅ javac version: $javac_version"

# Check JAVA_HOME
if [[ -n "$JAVA_HOME" ]]; then
    echo "✅ JAVA_HOME: $JAVA_HOME"
else
    echo "⚠️  JAVA_HOME not set"
fi

echo "✅ Java environment configured correctly"