#!/bin/bash
# Usage: ./scripts/bump-version.sh [major|minor|patch]

current=$(cat VERSION)
IFS='.' read -ra ADDR <<< "$current"
major=${ADDR[0]}
minor=${ADDR[1]}
patch=${ADDR[2]}

case $1 in
    major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
    minor)
        minor=$((minor + 1))
        patch=0
        ;;
    patch)
        patch=$((patch + 1))
        ;;
    *)
        echo "Usage: $0 [major|minor|patch]"
        exit 1
        ;;
esac

new_version="$major.$minor.$patch"
echo $new_version > VERSION
echo "Bumped version from $current to $new_version"
