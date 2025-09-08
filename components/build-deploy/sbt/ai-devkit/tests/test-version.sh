#!/bin/bash
# Test SBT version
set -e

echo "Checking SBT version..."

# Check if sbt command exists
if ! command -v sbt &> /dev/null; then
    echo "❌ sbt command not found"
    exit 1
fi

# Check SBT version (with timeout to prevent hanging)
echo "Getting SBT version..."
sbt_version_output=$(timeout 30 sbt -no-colors sbtVersion 2>/dev/null | grep "sbtVersion" | tail -1 || echo "")

if [[ -n "$sbt_version_output" ]]; then
    sbt_version=$(echo "$sbt_version_output" | sed 's/.*sbtVersion.*=[ ]*//' | sed 's/[^0-9.]*//g')
    echo "✅ SBT version: $sbt_version"
    
    # Check if it's a reasonable version (1.0+)
    if ! echo "$sbt_version" | awk -F. '{ if ($1 >= 1) exit 0; else exit 1}'; then
        echo "⚠️  SBT version may be outdated: $sbt_version"
    else
        echo "✅ SBT version is modern: $sbt_version"
    fi
else
    echo "ℹ️  Could not determine SBT version (may require network access)"
    # Try alternative method
    if timeout 10 sbt --version 2>/dev/null | grep -q "sbt"; then
        echo "✅ SBT command responds to --version"
    else
        echo "❌ SBT version check failed"
        exit 1
    fi
fi

# Check Scala version that SBT would use by default
echo "Checking default Scala version..."
if timeout 30 sbt -no-colors scalaVersion 2>/dev/null | grep -q "scalaVersion"; then
    scala_version=$(timeout 30 sbt -no-colors scalaVersion 2>/dev/null | grep "scalaVersion" | tail -1 | sed 's/.*scalaVersion.*=[ ]*//' | sed 's/[^0-9.]*//g')
    if [[ -n "$scala_version" ]]; then
        echo "✅ Default Scala version: $scala_version"
    fi
else
    echo "ℹ️  Could not determine default Scala version"
fi

# Check Java version that SBT uses
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}')
    echo "✅ Java version for SBT: $java_version"
else
    echo "❌ Java not found - SBT requires Java"
    exit 1
fi

# Check SBT_OPTS if set
if [[ -n "$SBT_OPTS" ]]; then
    echo "✅ SBT_OPTS: $SBT_OPTS"
else
    echo "ℹ️  SBT_OPTS not set (using defaults)"
fi

# Check for SBT repositories configuration
if [[ -f ~/.sbt/repositories ]]; then
    echo "✅ SBT repositories file exists at ~/.sbt/repositories"
else
    echo "ℹ️  SBT repositories file not found (using defaults)"
fi

# Check for global SBT plugins
if [[ -d ~/.sbt/1.0/plugins ]]; then
    echo "✅ Global SBT plugins directory exists"
else
    echo "ℹ️  Global SBT plugins directory not found"
fi

# Check ivy cache directory
if [[ -d ~/.ivy2/cache ]]; then
    echo "✅ Ivy cache directory exists at ~/.ivy2/cache"
else
    echo "ℹ️  Ivy cache directory not found (will be created on first use)"
fi

echo "✅ SBT version check completed"