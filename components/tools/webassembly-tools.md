#### WebAssembly Tools

A comprehensive suite of WebAssembly and wasmCloud development tools for building, testing, and deploying WebAssembly components.

**Installed Tools**:
- **wash (v1.0.0-beta.10)** - wasmCloud Shell for project management and deployment
- **wasm-tools (v1.240.0)** - Low-level WebAssembly module manipulation utilities
- **wasmtime (v38.0.3)** - Fast and secure WebAssembly runtime
- **wit-bindgen (v0.45.1)** - Generate language bindings from WIT definitions
- **wac (v0.6.1)** - WebAssembly Composition tool for linking components

**Prerequisites**:
This component requires a Rust installation (stable or nightly channel).

**wash - wasmCloud Shell**:

The primary tool for wasmCloud development with comprehensive project management capabilities.

```bash
# Create new projects
wash new component my-api        # Create new component
wash new provider my-provider    # Create new capability provider
wash new interface my-interface  # Create new WIT interface

# Build projects
wash build                       # Build current project
wash build --release             # Build optimized release

# Development workflow
wash dev                         # Start hot-reload dev server
wash dev --wit-world my-world    # Start with specific world

# Component inspection
wash inspect component.wasm      # Inspect component details
wash inspect --wit component.wasm  # Show WIT interface

# Registry operations
wash push localhost:5000/my-component:v1.0.0  # Push to OCI registry
wash pull localhost:5000/my-component:v1.0.0  # Pull from OCI registry

# wasmCloud host management
wash up                          # Start local wasmCloud host + NATS + wadm
wash down                        # Stop local wasmCloud environment
wash ui                          # Open wasmCloud dashboard

# Application deployment
wash app list                    # List deployed applications
wash app deploy wadm.yaml        # Deploy application manifest
wash app delete my-app           # Delete application
wash app validate wadm.yaml      # Validate manifest

# Plugin management
wash plugin install <name>       # Install wash plugin
wash plugin list                 # List installed plugins
```

**wasm-tools - Module Manipulation**:

Low-level utilities for inspecting and manipulating WebAssembly modules and components.

```bash
# Validate WebAssembly
wasm-tools validate module.wasm             # Validate module
wasm-tools validate component.wasm          # Validate component

# Print in human-readable format
wasm-tools print module.wasm                # Print as WAT
wasm-tools print component.wasm             # Print component structure

# Component operations
wasm-tools component new module.wasm        # Convert module to component
wasm-tools component wit component.wasm     # Extract WIT from component
wasm-tools component embed --world <world> --wit interface.wit module.wasm  # Embed WIT

# Composition
wasm-tools compose composed.wasm -c config.wasm  # Compose components
wasm-tools compose --config compose.yml     # Compose with config file

# Metadata operations
wasm-tools metadata show module.wasm        # Show metadata
wasm-tools metadata add --name "key" "value" module.wasm  # Add metadata

# Parsing and dumping
wasm-tools parse input.wat -o output.wasm   # Parse WAT to WASM
wasm-tools dump module.wasm                 # Dump detailed structure

# Strip debug info
wasm-tools strip module.wasm -o stripped.wasm  # Remove debug sections
```

**wasmtime - WebAssembly Runtime**:

Fast, secure runtime for executing and testing WebAssembly components locally.

```bash
# Run components
wasmtime run component.wasm                  # Execute component
wasmtime run --invoke function component.wasm  # Call specific function

# WASI preview 2 support
wasmtime serve component.wasm                # Serve HTTP component
wasmtime serve --addr 0.0.0.0:8080 component.wasm  # Custom address

# Component model
wasmtime component new module.wasm           # Componentize module
wasmtime component wit component.wasm        # Show component WIT

# Configuration
wasmtime run --dir /tmp::/ component.wasm    # Mount directory
wasmtime run --env KEY=value component.wasm  # Set environment variable
wasmtime run --wasi preview2 component.wasm  # Use WASI preview 2

# Debugging
wasmtime run --invoke-func-index 42 module.wasm  # Call by index
wasmtime run -g component.wasm               # Enable debug info

# Optimization
wasmtime compile component.wasm -o component.cwasm  # AOT compile
wasmtime run component.cwasm                 # Run precompiled

# Profiling
wasmtime run --profile=jitdump component.wasm  # Generate JIT profile
wasmtime run --profile=perfmap component.wasm  # Generate perf map
```

**wit-bindgen - Language Bindings**:

Generate language-specific bindings from WIT (WebAssembly Interface Type) definitions.

```bash
# Generate bindings for different languages
wit-bindgen rust --out-dir src/ interface.wit        # Rust bindings
wit-bindgen c --out-dir include/ interface.wit       # C bindings
wit-bindgen go --out-dir bindings/ interface.wit     # Go bindings (TinyGo)

# Rust-specific options
wit-bindgen rust \
  --world my-world \
  --out-dir src/bindings \
  --generate-all \
  interface.wit

# Generate for specific world
wit-bindgen rust --world example-world wit/

# Additional options
wit-bindgen rust \
  --out-dir src/ \
  --no-typescript \
  --derive Copy,Clone \
  interface.wit
```

**Typical wit-bindgen workflow**:
1. Define your interface in WIT format
2. Generate bindings: `wit-bindgen rust --out-dir src/bindings/ wit/`
3. Implement the generated traits in your Rust code
4. Build component: `wash build` or `cargo component build`

**wac - WebAssembly Composition**:

Declaratively compose WebAssembly components using the WAC language.

```bash
# Compose components
wac compose composition.wac -o composed.wasm         # Compose from WAC file
wac plug --plug plugin.wasm target.wasm -o result.wasm  # Plug components

# Parse and validate
wac parse composition.wac                     # Parse WAC file
wac parse --format json composition.wac       # Parse to JSON

# Example WAC file (composition.wac):
# let http-handler = new http:handler { ... }
# let db-client = new database:client { ... }
#
# export http-handler
# export db-client
```

**WAC language features**:
- Declarative component composition
- Instance creation and configuration
- Import/export management
- Type-safe component linking

**Common Development Workflows**:

**1. Create and test a wasmCloud component**:
```bash
# Create new component
wash new component hello-world
cd hello-world

# Start development server (auto-rebuilds on changes)
wash dev

# In another terminal, test the component
curl http://localhost:8000

# When ready, build release version
wash build --release
```

**2. Build and test a standalone WASM component**:
```bash
# Create Rust component project
cargo new --lib my-component
cd my-component

# Add to Cargo.toml:
# [lib]
# crate-type = ["cdylib"]

# Build as WASM
cargo build --target wasm32-wasi --release

# Convert to component
wasm-tools component new target/wasm32-wasi/release/my_component.wasm \
  -o component.wasm

# Test with wasmtime
wasmtime run component.wasm
```

**3. Compose multiple components**:
```bash
# Inspect components
wasm-tools component wit component-a.wasm
wasm-tools component wit component-b.wasm

# Create composition
wac plug --plug component-a.wasm component-b.wasm -o composed.wasm

# Validate result
wasm-tools validate composed.wasm
wasmtime run composed.wasm
```

**4. Generate and use WIT bindings**:
```bash
# Define interface in wit/interface.wit
# world my-world {
#   export run: func() -> string
# }

# Generate Rust bindings
wit-bindgen rust --world my-world --out-dir src/bindings/ wit/

# Implement in src/lib.rs
# struct MyComponent;
# impl Guest for MyComponent {
#     fn run() -> String { "Hello!".to_string() }
# }

# Build component
wash build
```

**Configuration Files**:
- `wasmcloud.toml` - wash project configuration
- `wadm.yaml` - wasmCloud application deployment manifest
- `Cargo.toml` - Rust project configuration (with component support)
- `*.wit` - WebAssembly Interface Type definitions
- `*.wac` - WebAssembly Composition declarations

**Best Practices**:
- Use `wash dev` for rapid iteration with hot-reload
- Validate all WASM with `wasm-tools validate` before deployment
- Test components locally with `wasmtime` before deploying to wasmCloud
- Use `wit-bindgen` to ensure type-safe interfaces between components
- Compose components at build time with `wac` for better performance
- Always specify explicit versions in project configurations
- Use `wash inspect` to verify component capabilities and interfaces

**Troubleshooting**:
```bash
# Check tool versions
wash --version
wasm-tools --version
wasmtime --version
wit-bindgen --version
wac --version

# Validate component structure
wasm-tools validate my-component.wasm
wasm-tools print my-component.wasm | head -50

# Debug wasmtime execution
wasmtime run --wasi-modules wasi_snapshot_preview1 component.wasm

# Check wash configuration
wash config get
wash doctor  # Diagnose common issues
```

**Additional Resources**:
- wasmCloud Documentation: https://wasmcloud.com/docs
- Component Model: https://component-model.bytecodealliance.org
- WIT Specification: https://component-model.bytecodealliance.org/design/wit.html
- wasmtime Guide: https://docs.wasmtime.dev
- Bytecode Alliance: https://bytecodealliance.org
