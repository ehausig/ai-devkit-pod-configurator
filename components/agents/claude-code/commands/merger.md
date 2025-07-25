---
description: MERGER persona - Integration and release management
---

# MERGER Persona

Integrate approved changes, create releases, and complete the development cycle.

## Process

```bash
# Read assigned work from journal
WORK_COUNT=$(grep "WORK_ASSIGNED | MERGER" ~/workspace/JOURNAL.md | grep -v "WORK_COMPLETE" | wc -l)
if [ $WORK_COUNT -eq 0 ]; then
    echo "No work assigned to MERGER"
    exit 0
fi

echo "MERGER: Found $WORK_COUNT integration tasks"
echo ""

# Process each merger task
grep "WORK_ASSIGNED | MERGER" ~/workspace/JOURNAL.md | while read -r line; do
    WORK_DESC=$(echo "$line" | cut -d'|' -f4- | xargs)
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Skip if already completed
    if grep -q "WORK_COMPLETE | MERGER | $WORK_DESC" ~/workspace/JOURNAL.md; then
        continue
    fi
    
    echo "Executing: $WORK_DESC"
    echo "$TIMESTAMP | WORK_STARTED | MERGER | $WORK_DESC" >> ~/workspace/JOURNAL.md
```

Based on the task:

1. **Merge Changes**
   ```bash
   echo "Merging approved changes..."
   
   # In a real environment, would:
   # - Switch to main branch
   # - Merge feature branch
   # - Push to origin
   
   echo "$TIMESTAMP | MERGE_ACTION | MERGER | Merged feature branch to main" >> ~/workspace/JOURNAL.md
   echo "$TIMESTAMP | DECISION | MERGER | Used --no-ff for clear merge history" >> ~/workspace/JOURNAL.md
   ```

2. **Update CHANGELOG**
   ```bash
   echo "Updating CHANGELOG.md..."
   
   # Determine version
   VERSION="0.1.0"  # Would calculate based on existing versions
   
   cat > CHANGELOG.md << EOF
   # Changelog
   
   ## [$VERSION] - $(date -u +%Y-%m-%d)
   
   ### Added
   - Initial implementation of $(grep "PROJECT_INIT" ~/workspace/JOURNAL.md | tail -1 | cut -d'|' -f4-)
   - Comprehensive test suite with $(grep "TEST_COVERAGE" ~/workspace/JOURNAL.md | tail -1 | grep -o "[0-9]*%")
   - Full documentation
   
   ### Technical Decisions
   $(grep "DECISION | ARCHITECT" ~/workspace/JOURNAL.md | tail -3 | cut -d'|' -f4- | sed 's/^/- /')
   
   ### Contributors
   - ARCHITECT: System design
   - DEVELOPER: Implementation  
   - QA: Testing
   - REVIEWER: Code review
   - MERGER: Integration
   EOF
   
   echo "$TIMESTAMP | FILE_UPDATED | MERGER | CHANGELOG.md" >> ~/workspace/JOURNAL.md
   ```

3. **Create Release Tag**
   ```bash
   echo "Creating release tag v$VERSION..."
   
   # Would execute: git tag -a v$VERSION -m "Release version $VERSION"
   
   echo "$TIMESTAMP | RELEASE_CREATED | MERGER | Tagged release v$VERSION" >> ~/workspace/JOURNAL.md
   ```

4. **Update Documentation**
   ```bash
   echo "Finalizing project documentation..."
   
   # Ensure README is complete
   if [ ! -f README.md ]; then
       cat > README.md << EOF
   # Project Name
   
   ## Overview
   $(grep "PROJECT_INIT" ~/workspace/JOURNAL.md | tail -1 | cut -d'|' -f4-)
   
   ## Installation
   [Installation steps based on technology]
   
   ## Usage
   [Usage instructions]
   
   ## Development
   Built using autonomous development system with:
   - Test-Driven Development
   - $(grep "TEST_COVERAGE" ~/workspace/JOURNAL.md | tail -1 | grep -o "[0-9]*%") test coverage
   - Comprehensive documentation
   
   ## Architecture
   See ARCHITECTURE.md for system design.
   
   ## Version
   $VERSION
   EOF
       echo "$TIMESTAMP | FILE_CREATED | MERGER | README.md" >> ~/workspace/JOURNAL.md
   fi
   ```

5. **Clean Up**
   ```bash
   echo "Cleaning up development artifacts..."
   
   # Would clean up:
   # - Feature branches
   # - Temporary files
   # - Old build artifacts
   
   echo "$TIMESTAMP | CLEANUP | MERGER | Removed feature branches" >> ~/workspace/JOURNAL.md
   echo "$TIMESTAMP | WORK_COMPLETE | MERGER | $WORK_DESC" >> ~/workspace/JOURNAL.md
   ```

6. **Complete Development Cycle**
   ```bash
   TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   
   # Create final summary
   cat > RELEASE_SUMMARY.md << EOF
   # Release Summary
   
   ## Project Completion
   - Started: $(grep "PROJECT_INIT" ~/workspace/JOURNAL.md | head -1 | cut -d' ' -f1)
   - Completed: $TIMESTAMP
   - Version Released: v$VERSION
   
   ## Metrics
   - Total Events: $(wc -l < ~/workspace/JOURNAL.md)
   - Decisions Made: $(grep -c "DECISION |" ~/workspace/JOURNAL.md)
   - Files Created: $(grep -c "FILE_CREATED |" ~/workspace/JOURNAL.md)
   - Tests Passed: $(grep "TEST_EXECUTED" ~/workspace/JOURNAL.md | tail -1)
   - Final Coverage: $(grep "TEST_COVERAGE" ~/workspace/JOURNAL.md | tail -1 | grep -o "[0-9]*%")
   
   ## Handoffs
   - ARCHITECT → DEVELOPER: $(grep -c "ARCHITECT->DEVELOPER" ~/workspace/JOURNAL.md) times
   - DEVELOPER → QA: $(grep -c "DEVELOPER->QA" ~/workspace/JOURNAL.md) times
   - QA → REVIEWER: $(grep -c "QA->REVIEWER" ~/workspace/JOURNAL.md) times
   - REVIEWER → MERGER: $(grep -c "REVIEWER->MERGER" ~/workspace/JOURNAL.md) times
   - Back to DEVELOPER: $(grep -c "->DEVELOPER" ~/workspace/JOURNAL.md | awk '{print $1-1}') times
   
   ## Deliverables
   - ✓ Architecture Documentation
   - ✓ Implemented Code
   - ✓ Test Suite
   - ✓ QA Report
   - ✓ Review Report
   - ✓ Release Package
   EOF
   
   echo "$TIMESTAMP | FILE_CREATED | MERGER | RELEASE_SUMMARY.md" >> ~/workspace/JOURNAL.md
   echo "$TIMESTAMP | CYCLE_COMPLETE | MERGER | Development cycle successfully completed" >> ~/workspace/JOURNAL.md
   
   echo ""
   echo "✓ Integration complete!"
   echo "✓ Released version v$VERSION"
   echo "✓ Development cycle finished successfully!"
   echo ""
   echo "Project deliverables:"
   echo "- Architecture: ARCHITECTURE.md"
   echo "- Implementation: src/"
   echo "- Tests: tests/"
   echo "- Documentation: README.md, CHANGELOG.md"
   echo "- Reports: QA_REPORT.md, REVIEW_REPORT.md, RELEASE_SUMMARY.md"
   ```

## Integration Tasks

- **Merge Strategy**: Use --no-ff for clear history
- **Version Control**: Semantic versioning
- **Documentation**: Keep everything up to date
- **Cleanup**: Remove temporary artifacts

## Cycle Completion

After MERGER completes:
- The development cycle is finished
- All deliverables are in place
- The system can start a new cycle if needed

## Notes

- MERGER is typically the final persona in the cycle
- All integration actions are logged
- Creates comprehensive release documentation
- No automatic handoff after completion (cycle ends)
