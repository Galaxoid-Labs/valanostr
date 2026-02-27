# ValaNostr

A Vala library implementing the [Nostr](https://nostr.com/) protocol's core functionality ([NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md)): key generation, event creation, event signing, event verification, and JSON serialization.

Wraps [libsecp256k1](https://github.com/bitcoin-core/secp256k1) via custom VAPI bindings for BIP-340 Schnorr signature operations.

**Platform:** Linux (uses the `getrandom(2)` syscall for cryptographic randomness).

## Quick Start

```bash
./check_deps.sh            # verify all dependencies are installed
meson setup build
meson compile -C build
meson test -C build
```

## Prerequisites

- **Vala** (>= 0.56)
- **Meson** (>= 0.60) and **Ninja**
- **GCC**
- **pkg-config**
- **GLib 2.0**, **GObject 2.0**, **Json-GLib 1.0** (development packages)

The static `libsecp256k1` library and headers are included in `lib/`.

### Check dependencies

Run the included script to verify everything is in place:

```bash
./check_deps.sh
```

It detects your distro, reports what's installed/missing, and prints the exact install command you need.

### Install system packages

#### Ubuntu / Debian

```bash
sudo apt install valac meson ninja-build gcc pkg-config \
                 libglib2.0-dev libjson-glib-dev
```

#### Fedora

```bash
sudo dnf install vala meson ninja-build gcc pkgconf-pkg-config \
                 glib2-devel json-glib-devel
```

#### Arch Linux

```bash
sudo pacman -S vala meson ninja gcc pkgconf glib2 json-glib
```

## Building

```bash
meson setup build
meson compile -C build
```

## Running Tests

```bash
meson test -C build
```

Or run the test binary directly for verbose TAP output:

```bash
./build/test_nostr
```

## Project Structure

```
valanostr/
  meson.build                   # Build configuration
  check_deps.sh                 # Dependency checker script
  vapi/
    secp256k1.vapi              # VAPI bindings for libsecp256k1
  lib/
    aarch64/
      libsecp256k1.a            # Static library — arm64
    x86_64/
      libsecp256k1.a            # Static library — x86_64
    include/
      secp256k1.h               # Headers (arch-independent)
      secp256k1_extrakeys.h
      secp256k1_schnorrsig.h
  src/
    nostr.vala                  # Library source (Nostr namespace)
  tests/
    test_nostr.vala             # Test suite
```

## API

Everything lives in the `Nostr` namespace.

### Nostr.Keypair

Manages Nostr identity key pairs (secp256k1 x-only public keys).

```vala
// Generate a new random keypair
var kp = Nostr.Keypair.generate ();

// Import from a known secret key (hex-encoded, 64 chars)
var kp = Nostr.Keypair.from_secret_key ("ab12cd...");

// Access the public key
string pubkey_hex = kp.public_key;        // 64-char hex string
uint8[] pubkey_raw = kp.public_key_bytes; // 32 raw bytes

// Sign a 32-byte message (returns 64-byte Schnorr signature)
uint8[] sig = kp.sign (msg32);
```

### Nostr.Event

Represents a NIP-01 event with signing, verification, and JSON serialization.

```vala
// Create a kind-1 text note
var ev = new Nostr.Event (1, "Hello, Nostr!");

// Add tags
ev.add_tag ("e", "referenced_event_id");
ev.add_tag ("p", "referenced_pubkey");

// Sign the event (sets pubkey, computes id, creates signature)
ev.sign (keypair);

// Verify the signature
bool valid = ev.verify ();

// Serialize to JSON
string json = ev.to_json ();

// Parse from JSON
var ev2 = Nostr.Event.from_json (json);
```

#### Event Fields

| Field        | Type                                     | Description                        |
|--------------|------------------------------------------|------------------------------------|
| `id`         | `string`                                 | Event ID (64-char hex SHA-256)     |
| `pubkey`     | `string`                                 | Author public key (64-char hex)    |
| `created_at` | `int64`                                  | Unix timestamp                     |
| `kind`       | `int`                                    | Event kind (e.g. 1 = text note)    |
| `tags`       | `GenericArray<GenericArray<string>>`      | Array of tag arrays                |
| `content`    | `string`                                 | Event content                      |
| `sig`        | `string`                                 | Schnorr signature (128-char hex)   |

### Utility Functions

```vala
// Hex encoding/decoding
string hex = Nostr.hex_encode (raw_bytes);
uint8[] bytes = Nostr.hex_decode ("deadbeef");
```

## Full Example

```vala
void main () {
    // Generate a keypair
    var kp = Nostr.Keypair.generate ();
    print ("Public key: %s\n", kp.public_key);

    // Create and sign an event
    var ev = new Nostr.Event (1, "Hello from ValaNostr!");
    ev.add_tag ("t", "vala");
    ev.sign (kp);

    // Verify and serialize
    assert (ev.verify ());
    print ("%s\n", ev.to_json ());

    // Round-trip through JSON
    try {
        var ev2 = Nostr.Event.from_json (ev.to_json ());
        assert (ev2.verify ());
    } catch (Error e) {
        printerr ("Parse error: %s\n", e.message);
    }
}
```

## Using in Another Project

### System install

```bash
cd valanostr
meson setup build
meson compile -C build
sudo meson install -C build
```

Then in your project's `meson.build`:

```meson
valanostr_dep = dependency('valanostr')
executable('myapp', 'main.vala', dependencies: [valanostr_dep])
```

### Meson subproject

Place valanostr in your project's `subprojects/valanostr/` directory (or use a [wrap file](https://mesonbuild.com/Wrap-dependency-system-manual.html)), then in your `meson.build`:

```meson
valanostr_proj = subproject('valanostr')
valanostr_dep = valanostr_proj.get_variable('valanostr_dep')
executable('myapp', 'main.vala', dependencies: [valanostr_dep])
```

## License

MIT License. See [LICENSE](LICENSE) for details. libsecp256k1 is distributed under the MIT license.
