void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/nostr/keypair/generate", test_keypair_generate);
    Test.add_func ("/nostr/keypair/from_secret_key", test_keypair_from_secret_key);
    Test.add_func ("/nostr/event/sign_and_verify", test_event_sign_and_verify);
    Test.add_func ("/nostr/event/verify_tampered", test_event_verify_tampered);
    Test.add_func ("/nostr/event/json_roundtrip", test_event_json_roundtrip);
    Test.add_func ("/nostr/event/id_computation", test_event_id_computation);

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
