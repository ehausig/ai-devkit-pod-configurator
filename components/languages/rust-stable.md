#### Rust (Stable)

**Environment Setup**
```bash
# Rust doesn't use virtual environments
# Ensure using stable toolchain
rustup default stable
rustup update
```

**Project Init**
```bash
# Create new binary project
cargo new myproject
cd myproject

# Create library project
cargo new --lib mylib

# Initialize in existing directory
cargo init
```

**Dependencies**
```bash
# Add dependency (edit Cargo.toml)
cargo add tokio --features full
cargo add serde --features derive
cargo add clap --features derive

# Update dependencies
cargo update

# Check for outdated
cargo install cargo-outdated
cargo outdated
```

**Format & Lint**
```bash
# Format code
cargo fmt

# Check formatting without changes
cargo fmt -- --check

# Lint with clippy
cargo clippy
cargo clippy -- -D warnings  # Fail on warnings
```

**Testing**

*Unit Tests*
```bash
# Run unit tests
cargo test --lib

# Run specific test
cargo test test_name

# With output
cargo test -- --nocapture

# Example structure
// src/lib.rs or src/module.rs
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_calculate() {
        assert_eq!(calculate(2, 3), 5);
    }
}
```

*Integration Tests*
```bash
# Run integration tests
cargo test --test '*'

# Example: API integration test
// tests/api_integration.rs
use reqwest;

#[tokio::test]
async fn test_api_endpoint() {
    let response = reqwest::get("http://localhost:8080/health")
        .await
        .unwrap();
    assert_eq!(response.status(), 200);
}

# Database integration
// tests/db_integration.rs
#[sqlx::test]
async fn test_user_creation(pool: PgPool) {
    let user = create_user(&pool, "test@example.com").await.unwrap();
    assert!(user.id > 0);
}
```

*User Simulation Tests*
```bash
# TUI testing with Microsoft TUI Test
npx @microsoft/tui-test tests/e2e/

# Web automation with thirtyfour
cargo test --test e2e_tests

# Example: Browser automation
// tests/e2e_tests.rs
use thirtyfour::prelude::*;

#[tokio::test]
async fn test_login_flow() -> WebDriverResult<()> {
    let driver = WebDriver::new("http://localhost:9515", DesiredCapabilities::chrome()).await?;
    driver.goto("http://localhost:3000").await?;
    driver.find(By::Name("email")).await?.send_keys("user@example.com").await?;
    driver.find(By::Name("password")).await?.send_keys("password").await?;
    driver.find(By::Css("button[type='submit']")).await?.click().await?;
    assert_eq!(driver.current_url().await?, "http://localhost:3000/dashboard");
    Ok(())
}
```

**Build**
```bash
# Debug build (fast compile, slow runtime)
cargo build

# Release build (slow compile, fast runtime)
cargo build --release

# Check for errors without building
cargo check
```

**Run**
```bash
# Run debug build
cargo run

# Run release build
cargo run --release

# Run with arguments
cargo run -- --arg1 value

# Watch mode (install cargo-watch first)
cargo install cargo-watch
cargo watch -x run
```
