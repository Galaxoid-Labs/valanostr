# ValaNostr

[![CI](https://github.com/Galaxoid-Labs/valanostr/actions/workflows/ci.yml/badge.svg)](https://github.com/Galaxoid-Labs/valanostr/actions/workflows/ci.yml)

A Vala library implementing the [Nostr](https://nostr.com/) protocol's core functionality ([NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md), [NIP-19](https://github.com/nostr-protocol/nips/blob/master/19.md)): key generation, event creation, event signing, event verification, JSON serialization, and bech32 encoding/decoding.

Wraps [libsecp256k1](https://github.com/bitcoin-core/secp256k1) via custom VAPI bindings for BIP-340 Schnorr signature operations.

**Platform:** Linux (uses the `getrandom(2)` syscall for cryptographic randomness).

## Quick Start

```bash
git clone --recursive https://github.com/jdavis/valanostr.git
cd valanostr
./check_deps.sh            # verify all dependencies are installed
meson setup build
meson compile -C build
meson test -C build
```

If you already cloned without `--recursive`, initialize the submodule:

```bash
git submodule update --init
```

## Prerequisites

- **Vala** (>= 0.56)
- **Meson** (>= 0.60) and **Ninja**
- **GCC**
- **pkg-config**
- **GLib 2.0**, **GObject 2.0**, **Json-GLib 1.0** (development packages)

`libsecp256k1` is included as a git submodule and built from source automatically.

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
  deps/
    secp256k1/                  # git submodule (bitcoin-core/secp256k1)
  src/
    nostr.vala                  # NIP-01: keys, events, signing
    nip19.vala                  # NIP-19: bech32 encoding/decoding
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

### NIP-19: Bech32 Encoding (npub, nsec, note)

Encode and decode keys and event IDs as human-readable bech32 strings.

```vala
// Encode hex keys to bech32
string npub = Nostr.encode_npub (kp.public_key);
// "npub10elfcs4fr0l0r8af98jlmgdh9c8tcxjvz9qkw038js35mp4dma8qzvjptg"

string nsec = Nostr.encode_nsec (secret_key_hex);
string note = Nostr.encode_note (event_id_hex);

// Decode bech32 back to hex
string pubkey_hex = Nostr.decode_npub (npub);
string seckey_hex = Nostr.decode_nsec (nsec);
string event_id_hex = Nostr.decode_note (note);
```

### NIP-19: Shareable Identifiers (nprofile, nevent, naddr)

Encode and decode entities with optional relay hints and metadata using TLV format.

```vala
// Encode a profile with relay hints
string[] relays = { "wss://relay.example.com", "wss://relay2.example.com" };
string nprofile = Nostr.encode_nprofile (pubkey_hex, relays);

// Decode a profile
var profile = Nostr.decode_nprofile (nprofile);
print ("pubkey: %s\n", profile.pubkey);
for (uint i = 0; i < profile.relays.length; i++) {
    print ("relay: %s\n", profile.relays[i]);
}

// Encode an event with relay, author, and kind
string nevent = Nostr.encode_nevent (event_id_hex, relays, author_hex, 1);

// Decode an event
var event = Nostr.decode_nevent (nevent);
print ("id: %s, author: %s, kind: %d\n", event.id, event.author, event.kind);

// Encode an addressable event (NIP-33)
string naddr = Nostr.encode_naddr ("my-article", pubkey_hex, 30023, relays);

// Decode an addressable event
var addr = Nostr.decode_naddr (naddr);
print ("d-tag: %s, kind: %d\n", addr.identifier, addr.kind);
```

### Utility Functions

```vala
// Hex encoding/decoding
string hex = Nostr.hex_encode (raw_bytes);
uint8[] bytes = Nostr.hex_decode ("deadbeef");

// Low-level bech32 encoding/decoding
string encoded = Nostr.bech32_encode ("custom", raw_bytes);
uint8[] decoded = Nostr.bech32_decode (encoded, out hrp);
```

## Full Example

```vala
void main () {
    // Generate a keypair
    var kp = Nostr.Keypair.generate ();
    print ("Public key: %s\n", kp.public_key);
    print ("npub: %s\n", Nostr.encode_npub (kp.public_key));

    // Create and sign an event
    var ev = new Nostr.Event (1, "Hello from ValaNostr!");
    ev.add_tag ("t", "vala");
    ev.sign (kp);

    // Verify and serialize
    assert (ev.verify ());
    print ("note: %s\n", Nostr.encode_note (ev.id));
    print ("%s\n", ev.to_json ());

    // Share as an nevent with relay hints
    string[] relays = { "wss://relay.example.com" };
    print ("nevent: %s\n", Nostr.encode_nevent (ev.id, relays, kp.public_key, 1));

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
