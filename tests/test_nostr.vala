void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/nostr/keypair/generate", test_keypair_generate);
    Test.add_func ("/nostr/keypair/from_secret_key", test_keypair_from_secret_key);
    Test.add_func ("/nostr/event/sign_and_verify", test_event_sign_and_verify);
    Test.add_func ("/nostr/event/verify_tampered", test_event_verify_tampered);
    Test.add_func ("/nostr/event/json_roundtrip", test_event_json_roundtrip);
    Test.add_func ("/nostr/event/id_computation", test_event_id_computation);

    Test.add_func ("/nostr/nip19/npub_encode", test_npub_encode);
    Test.add_func ("/nostr/nip19/npub_decode", test_npub_decode);
    Test.add_func ("/nostr/nip19/nsec_roundtrip", test_nsec_roundtrip);
    Test.add_func ("/nostr/nip19/note_roundtrip", test_note_roundtrip);
    Test.add_func ("/nostr/nip19/nprofile_decode", test_nprofile_decode);
    Test.add_func ("/nostr/nip19/nprofile_roundtrip", test_nprofile_roundtrip);
    Test.add_func ("/nostr/nip19/nevent_roundtrip", test_nevent_roundtrip);
    Test.add_func ("/nostr/nip19/naddr_roundtrip", test_naddr_roundtrip);

    Test.run ();
}

void test_keypair_generate () {
    var kp = Nostr.Keypair.generate ();

    // Public key should be 32 bytes
    assert (kp.public_key_bytes.length == 32);

    // Hex-encoded public key should be 64 characters
    assert (kp.public_key.length == 64);

    // Generate a second keypair - should be different
    var kp2 = Nostr.Keypair.generate ();
    assert (kp.public_key != kp2.public_key);
}

void test_keypair_from_secret_key () {
    // Secret key = 1 produces the generator point x-coordinate as the public key
    var secret_hex = "0000000000000000000000000000000000000000000000000000000000000001";
    var expected_pubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798";

    try {
        var kp = Nostr.Keypair.from_secret_key (secret_hex);
        assert (kp.public_key == expected_pubkey);
        assert (kp.public_key_bytes.length == 32);
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

void test_event_sign_and_verify () {
    var kp = Nostr.Keypair.generate ();

    var ev = new Nostr.Event (1, "Hello, Nostr!");
    ev.sign (kp);

    // Event should have id, pubkey, and sig set
    assert (ev.id.length == 64);
    assert (ev.pubkey == kp.public_key);
    assert (ev.sig.length == 128);

    // Signature should verify
    assert (ev.verify ());
}

void test_event_verify_tampered () {
    var kp = Nostr.Keypair.generate ();

    var ev = new Nostr.Event (1, "Original content");
    ev.sign (kp);
    assert (ev.verify ());

    // Save original sig
    var original_sig = ev.sig;

    // Tamper with the signature by flipping a hex character
    var sig_bytes = ev.sig.data;
    if (sig_bytes[0] == 'a') {
        sig_bytes[0] = 'b';
    } else {
        sig_bytes[0] = 'a';
    }
    ev.sig = (string) sig_bytes;

    // Verification should fail with tampered signature
    assert (!ev.verify ());

    // Restore and verify it works again
    ev.sig = original_sig;
    assert (ev.verify ());
}

void test_event_json_roundtrip () {
    var kp = Nostr.Keypair.generate ();

    var ev = new Nostr.Event (1, "Test message");
    ev.add_tag ("e", "abc123def456");
    ev.add_tag ("p", "deadbeef01234567");
    ev.sign (kp);

    // Serialize to JSON
    var json = ev.to_json ();
    assert (json.length > 0);

    // Parse back from JSON
    try {
        var ev2 = Nostr.Event.from_json (json);

        assert (ev2.id == ev.id);
        assert (ev2.pubkey == ev.pubkey);
        assert (ev2.created_at == ev.created_at);
        assert (ev2.kind == ev.kind);
        assert (ev2.content == ev.content);
        assert (ev2.sig == ev.sig);

        // Verify tags
        assert (ev2.tags.length == 2);
        assert (ev2.tags[0].length == 2);
        assert (ev2.tags[0][0] == "e");
        assert (ev2.tags[0][1] == "abc123def456");
        assert (ev2.tags[1][0] == "p");
        assert (ev2.tags[1][1] == "deadbeef01234567");

        // Re-parsed event should still verify
        assert (ev2.verify ());
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

// ── NIP-19 tests ────────────────────────────────────────────

void test_npub_encode () {
    // NIP-19 spec test vector
    var hex = "7e7e9c42a91bfef19fa929e5fda1b72e0ebc1a4c1141673e2794234d86addf4e";
    var expected = "npub10elfcs4fr0l0r8af98jlmgdh9c8tcxjvz9qkw038js35mp4dma8qzvjptg";
    assert (Nostr.encode_npub (hex) == expected);
}

void test_npub_decode () {
    // NIP-19 spec test vector
    var npub = "npub10elfcs4fr0l0r8af98jlmgdh9c8tcxjvz9qkw038js35mp4dma8qzvjptg";
    var expected = "7e7e9c42a91bfef19fa929e5fda1b72e0ebc1a4c1141673e2794234d86addf4e";
    try {
        assert (Nostr.decode_npub (npub) == expected);
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

void test_nsec_roundtrip () {
    // NIP-19 spec test vector
    var hex = "67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa";
    var expected_nsec = "nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5";
    var encoded = Nostr.encode_nsec (hex);
    assert (encoded == expected_nsec);

    try {
        var decoded = Nostr.decode_nsec (encoded);
        assert (decoded == hex);
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

void test_note_roundtrip () {
    var hex = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d";
    var encoded = Nostr.encode_note (hex);
    assert (encoded.has_prefix ("note1"));

    try {
        var decoded = Nostr.decode_note (encoded);
        assert (decoded == hex);
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

void test_nprofile_decode () {
    // NIP-19 spec test vector
    var nprofile = "nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p";
    try {
        var result = Nostr.decode_nprofile (nprofile);
        assert (result.pubkey == "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d");
        assert (result.relays.length == 2);
        assert (result.relays[0] == "wss://r.x.com");
        assert (result.relays[1] == "wss://djbas.sadkb.com");
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

void test_nprofile_roundtrip () {
    var pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d";
    string[] relays = { "wss://relay.example.com", "wss://relay2.example.com" };

    var encoded = Nostr.encode_nprofile (pubkey, relays);
    assert (encoded.has_prefix ("nprofile1"));

    try {
        var decoded = Nostr.decode_nprofile (encoded);
        assert (decoded.pubkey == pubkey);
        assert (decoded.relays.length == 2);
        assert (decoded.relays[0] == "wss://relay.example.com");
        assert (decoded.relays[1] == "wss://relay2.example.com");
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

void test_nevent_roundtrip () {
    var event_id = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d";
    var author = "7e7e9c42a91bfef19fa929e5fda1b72e0ebc1a4c1141673e2794234d86addf4e";
    string[] relays = { "wss://relay.example.com" };

    var encoded = Nostr.encode_nevent (event_id, relays, author, 1);
    assert (encoded.has_prefix ("nevent1"));

    try {
        var decoded = Nostr.decode_nevent (encoded);
        assert (decoded.id == event_id);
        assert (decoded.relays.length == 1);
        assert (decoded.relays[0] == "wss://relay.example.com");
        assert (decoded.author == author);
        assert (decoded.kind == 1);
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

void test_naddr_roundtrip () {
    var pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d";
    string[] relays = { "wss://relay.example.com" };

    var encoded = Nostr.encode_naddr ("my-article", pubkey, 30023, relays);
    assert (encoded.has_prefix ("naddr1"));

    try {
        var decoded = Nostr.decode_naddr (encoded);
        assert (decoded.identifier == "my-article");
        assert (decoded.pubkey == pubkey);
        assert (decoded.kind == 30023);
        assert (decoded.relays.length == 1);
        assert (decoded.relays[0] == "wss://relay.example.com");
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}

void test_event_id_computation () {
    try {
        var kp = Nostr.Keypair.from_secret_key (
            "0000000000000000000000000000000000000000000000000000000000000001"
        );

        var ev = new Nostr.Event (1, "Hello");
        ev.created_at = 1234567890;

        ev.compute_id (kp.public_key);

        // The id should be a 64-char hex string (32 bytes SHA-256)
        assert (ev.id.length == 64);

        // Computing the id again with the same inputs should produce the same result
        var first_id = ev.id;
        ev.compute_id (kp.public_key);
        assert (ev.id == first_id);
    } catch (Error e) {
        Test.message ("Unexpected error: %s", e.message);
        assert_not_reached ();
    }
}
