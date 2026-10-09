#!/bin/bash
# Test Gradle version
set -e

echo "Checking Gradle version..."

# Check if gradle command exists
if ! command -v gradle &> /dev/null; then
    echo "❌ gradle command not found"
    exit 1
fi

# Check Gradle version
gradle_version=$(gradle --version 2>&1 | grep "Gradle" | head -1)
echo "✅ $gradle_version"

# Extract version number and validate
version_number=$(echo "$gradle_version" | sed 's/Gradle //' | awk '{print $1}')
if [[ -z "$version_number" ]]; then
    echo "❌ Could not determine Gradle version"
    exit 1
fi

echo "✅ Gradle version number: $version_number"

# Check if it's a reasonable version (5.0+)
if ! echo "$version_number" | awk -F. '{ if ($1 >= 5) exit 0; else exit 1}'; then
    echo "⚠️  Gradle version may be outdated: $version_number"
else
    echo "✅ Gradle version is modern: $version_number"
fi

# Check Gradle daemon status
gradle_daemon_status=$(gradle --status 2>/dev/null | grep "daemon" || echo "No daemons running")
echo "✅ Gradle daemon status: $gradle_daemon_status"

# Check Java version compatibility
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}')
    echo "✅ Java version for Gradle: $java_version"
else
    echo "⚠️  Java not found - Gradle requires Java"
fi

# Check GRADLE_HOME if set
if [[ -n "$GRADLE_HOME" ]]; then
    echo "✅ GRADLE_HOME: $GRADLE_HOME"
else
    echo "ℹ️  GRADLE_HOME not set (using system installation)"
fi

echo "✅ Gradle version check completed"