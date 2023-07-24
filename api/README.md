# Simple Key-Value API

This is a very simple key-value store built with Rust.

The API depends on Redis. By default, the API connects to `localhost:6379`.
You can change the host/port of the Redis server by setting the `REDIS_HOST`
environment variable.

# Run

To run the app, get `rustup` and install Rust stable. That will give you a full
Rust toolchain, including Cargo.

With that done, fire it up:

`cargo run`

# Build

`cargo build --release`

The executable API binary will be in `build/release/api`.
