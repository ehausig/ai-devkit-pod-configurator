#!/bin/bash
# Test Maven version
set -e

echo "Checking Maven version..."

# Check if mvn command exists
if ! command -v mvn &> /dev/null; then
    echo "❌ mvn command not found"
    exit 1
fi

# Check Maven version
maven_version=$(mvn --version | head -1)
echo "✅ $maven_version"

# Extract version number and validate
version_number=$(echo "$maven_version" | sed 's/Apache Maven //' | awk '{print $1}')
if [[ -z "$version_number" ]]; then
    echo "❌ Could not determine Maven version"
    exit 1
fi

echo "✅ Maven version number: $version_number"

# Check if it's a reasonable version (3.6+)
if ! echo "$version_number" | awk -F. '{ if ($1 >= 3 && $2 >= 6) exit 0; else exit 1}'; then
    echo "⚠️  Maven version may be outdated: $version_number"
else
    echo "✅ Maven version is modern: $version_number"
fi

# Check Java version compatibility
java_info=$(mvn --version | grep "Java version:")
if [[ -n "$java_info" ]]; then
    echo "✅ $java_info"
else
    echo "❌ Could not determine Java version for Maven"
    exit 1
fi

# Check Maven home
maven_home=$(mvn --version | grep "Maven home:")
if [[ -n "$maven_home" ]]; then
    echo "✅ $maven_home"
else
    echo "❌ Could not determine Maven home"
    exit 1
fi

# Check Java home
java_home_info=$(mvn --version | grep "Java home:")
if [[ -n "$java_home_info" ]]; then
    echo "✅ $java_home_info"
else
    echo "❌ Could not determine Java home"
    exit 1
fi

# Check default locale
locale_info=$(mvn --version | grep "Default locale:" || echo "Default locale: Not specified")
echo "✅ $locale_info"

# Check OS name
os_info=$(mvn --version | grep "OS name:")
if [[ -n "$os_info" ]]; then
    echo "✅ $os_info"
fi

# Check M2_HOME if set
if [[ -n "$M2_HOME" ]]; then
    echo "✅ M2_HOME: $M2_HOME"
else
    echo "ℹ️  M2_HOME not set (using system installation)"
fi

# Check settings file
if [[ -f ~/.m2/settings.xml ]]; then
    echo "✅ Maven settings.xml exists at ~/.m2/settings.xml"
else
    echo "ℹ️  Maven settings.xml not found (using defaults)"
fi

# Check repository directory
if [[ -d ~/.m2/repository ]]; then
    echo "✅ Maven local repository exists at ~/.m2/repository"
else
    echo "ℹ️  Maven local repository not found (will be created on first use)"
fi

echo "✅ Maven version check completed"