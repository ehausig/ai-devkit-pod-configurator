#### Rust (Nightly)

**Environment Setup**
```bash
# Install and set nightly as default
rustup install nightly
rustup default nightly

# Or use per-project
rustup override set nightly

# Update nightly
rustup update nightly
```

**Project Init**
```bash
# Same as stable
cargo new myproject
cd myproject

# Enable nightly features in main.rs
echo '#![feature(async_fn_in_trait)]' >> src/main.rs

# Create rust-toolchain.toml
echo '[toolchain]
channel = "nightly"' > rust-toolchain.toml
```

**Dependencies**
```bash
# Same commands as stable
cargo add tokio --features full
cargo add serde --features derive

# Nightly-only crates
cargo add async-trait
cargo add rocket  # Requires nightly

# Update
cargo update
```

**Format & Lint**
```bash
# Format (same as stable)
cargo +nightly fmt

# Clippy with nightly
cargo +nightly clippy

# Expanded macros (nightly feature)
cargo +nightly expand

# Miri for UB detection
rustup +nightly component add miri
cargo +nightly miri run
```

**Testing**

*Unit Tests*
```bash
# Run unit tests only
cargo +nightly test --lib

# Run with nightly features
cargo +nightly test --features unstable

# Example unit tests
// src/lib.rs or module files
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_basic_math() {
        assert_eq!(add(2, 3), 5);
    }
    
    // Nightly: async tests with async-std
    #[async_std::test]
    async fn test_async_operation() {
        let result = fetch_data().await;
        assert!(result.is_ok());
    }
    
    // Property testing with proptest
    use proptest::prelude::*;
    
    proptest! {
        #[test]
        fn test_addition_commutative(a: i32, b: i32) {
            assert_eq!(add(a, b), add(b, a));
        }
    }
}
```

*Integration Tests*
```bash
# Run integration tests
cargo +nightly test --test '*'

# Database integration with sqlx
// tests/database_integration.rs
#[sqlx::test]
async fn test_user_creation(pool: PgPool) -> sqlx::Result<()> {
    let user = create_user(&pool, "test@example.com").await?;
    assert!(user.id > 0);
    
    let found = find_user_by_email(&pool, "test@example.com").await?;
    assert_eq!(found.id, user.id);
    Ok(())
}

# API integration tests
// tests/api_integration.rs
#[tokio::test]
async fn test_health_endpoint() {
    let app = create_app().await;
    let response = app.oneshot(
        Request::builder()
            .uri("/health")
            .body(Body::empty())
            .unwrap()
    ).await.unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
}
```

*User Simulation Tests*
```bash
# TUI testing with Microsoft TUI Test
npx @microsoft/tui-test tests/e2e/

# Browser automation
cargo +nightly test --test e2e_tests

# Example with fantoccini
// tests/e2e_tests.rs
#[tokio::test]
async fn test_login_flow() -> Result<(), fantoccini::error::CmdError> {
    let mut caps = DesiredCapabilities::chrome();
    let driver = ClientBuilder::native()
        .capabilities(caps)
        .connect("http://localhost:9515")
        .await?;
        
    driver.goto("http://localhost:3000").await?;
    driver.find(Locator::Css("input[name='email']"))
        .await?
        .send_keys("user@example.com")
        .await?;
    driver.find(Locator::Css("button[type='submit']"))
        .await?
        .click()
        .await?;
        
    let url = driver.current_url().await?;
    assert!(url.as_ref().ends_with("/dashboard"));
    
    driver.close().await
}
```

**Build**
```bash
# Standard build
cargo +nightly build

# With specific features
cargo +nightly build --features unstable

# Build std library
cargo +nightly build -Z build-std

# Release with nightly optimizations
cargo +nightly build --release
```

**Run**
```bash
# Run with nightly
cargo +nightly run

# Watch mode
cargo watch -x "run +nightly"

# With feature flags
cargo +nightly run --features experimental

# Direct execution
./target/debug/myapp
```
