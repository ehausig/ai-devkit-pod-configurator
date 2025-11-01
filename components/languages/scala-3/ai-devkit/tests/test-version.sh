#!/bin/bash
# Test Scala 3 version
set -e

echo "Checking Scala version..."

# Check if scala command exists
if ! command -v scala &> /dev/null; then
    echo "❌ scala command not found"
    exit 1
fi

# Check if scalac command exists
if ! command -v scalac &> /dev/null; then
    echo "❌ scalac command not found"
    exit 1
fi

# Check Scala version
scala_version=$(scala -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
if [[ ! "$scala_version" =~ ^3\. ]]; then
    echo "❌ Wrong Scala version: $scala_version (expected 3.x)"
    exit 1
fi

echo "✅ Scala version: $scala_version"

# Check scalac version
scalac_version=$(scalac -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
echo "✅ scalac version: $scalac_version"

# Check if sbt is available (common build tool)
if command -v sbt &> /dev/null; then
    sbt_version=$(sbt --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -n1)
    echo "✅ sbt version: $sbt_version"
else
    echo "⚠️  sbt not found (may need to install separately)"
fi

# Check SCALA_HOME if set
if [[ -n "$SCALA_HOME" ]]; then
    echo "✅ SCALA_HOME: $SCALA_HOME"
else
    echo "⚠️  SCALA_HOME not set"
fi

echo "✅ Scala environment configured correctly"