#!/bin/bash
# Create a release PR from develop to main

# Get current version
VERSION=$(cat VERSION)

# Get changes from changelog for this version
CHANGES=$(awk "/## \[Unreleased\]/{flag=1; next} /## \[/{flag=0} flag" CHANGELOG.md | head -20)

# Create PR
gh pr create --base main --head develop \
  --title "chore: release v${VERSION}" \
  --body "## Release v${VERSION}

### Summary
$(echo "$CHANGES" | grep -E "^###" | sed 's/### /- /')

### Changes
\`\`\`
$CHANGES
\`\`\`

### Checklist
- [x] Version bumped to ${VERSION}
- [x] CHANGELOG.md updated
- [x] All changes reviewed
- [x] Ready for production

See [CHANGELOG.md](https://github.com/ehausig/ai-devkit-pod-configurator/blob/develop/CHANGELOG.md) for complete details.

---
*This PR was created using \`scripts/create-release-pr.sh\`*"
