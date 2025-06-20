#### Rust (Nightly)

**Unstable Features**: Use `#![feature(name)]` in code

**Commands**:
- Build: `cargo +nightly build`
- Run: `cargo +nightly run`
- Watch: `cargo watch -x "run +nightly"`
- Test: `cargo +nightly test`

**Advanced Tools**:
- Miri: `rustup +nightly component add miri`
- Expand macros: `cargo +nightly expand`
- Build std: `cargo +nightly build -Z build-std`

**Dependency Compatibility** (same as stable):
```toml
async-graphql = "5.0"
axum = "0.6"
tokio = { version = "1", features = ["full"] }
```

**Switching**: `cargo +stable build` to use stable

**Warning**: Nightly may break. Pin versions in CI.
