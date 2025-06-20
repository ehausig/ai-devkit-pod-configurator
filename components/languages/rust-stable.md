#### Rust (Stable)

**Quick Start**:
- New project: `cargo new myproject`
- Build: `cargo build --release`
- Run: `cargo run`
- Test: `cargo test`

**Watch Mode** (auto-recompile):
- `cargo watch -x run`
- `cargo watch -x test`
- `cargo watch -c -x run` (clear screen)

**Testing**:
```rust
#[test]
fn test_function() {
    assert_eq!(2 + 2, 4);
}

#[tokio::test]
async fn test_async() {
    // async test
}
```

**Dependency Compatibility**:
```toml
# Common async stack
async-graphql = "5.0"
async-graphql-axum = "5.0"
axum = "0.6"
tokio = { version = "1", features = ["full"] }
```

Check conflicts: `cargo tree -d`

**Tools**: `cargo fmt`, `cargo clippy`, `cargo doc --open`
