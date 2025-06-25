#### Maven

**Quick Start**: `mvn archetype:generate -DgroupId=com.example -DartifactId=myapp -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false`

**Build Lifecycle**:
- `mvn clean package` - Clean and build JAR/WAR
- `mvn test` - Run tests only
- `mvn install` - Install to local repo
- `mvn verify` - Run integration tests

**Testing**:
- Run specific test: `mvn test -Dtest=MyTest`
- Skip tests: `mvn package -DskipTests`
- Test reports in `target/surefire-reports/`

**Dependencies**:
- Show tree: `mvn dependency:tree`
- Force update: `mvn clean install -U`
- Check updates: `mvn versions:display-dependency-updates`

**Performance**: `mvn -T 4 clean package` (4 threads)

**Common Issues**: Version conflicts → use `mvn dependency:tree -Dverbose`
