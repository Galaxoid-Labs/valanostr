    [CCode (cname = "getrandom", cheader_filename = "sys/random.h")]
    private static extern ssize_t getrandom (void* buf, size_t buflen, uint flags);

namespace Nostr {

    private static Secp256k1.Context? _ctx = null;

    private static unowned Secp256k1.Context get_context () {
        if (_ctx == null) {
            _ctx = new Secp256k1.Context (Secp256k1.CONTEXT_NONE);
            uint8 seed[32];
            fill_random (seed);
            _ctx.randomize (seed);
        }
        return _ctx;
    }

    private static void fill_random (uint8[] buf) {
        size_t off = 0;
        while (off < buf.length) {
            ssize_t r = getrandom ((void*) (&buf[off]), buf.length - off, 0);
            assert (r >= 0);
            off += (size_t) r;
        }
    }

    public static string hex_encode (uint8[] data) {
        var builder = new StringBuilder.sized (data.length * 2);
        foreach (var b in data) {
            builder.append_printf ("%02x", b);
        }
        return builder.str;
    }

    public static uint8[] hex_decode (string hex) {
        var len = hex.length / 2;
        var result = new uint8[len];
        for (int i = 0; i < len; i++) {
            uint8 hi = char_to_nibble (hex[i * 2]);
            uint8 lo = char_to_nibble (hex[i * 2 + 1]);
            result[i] = (hi << 4) | lo;
        }
        return result;
    }

    private static uint8 char_to_nibble (char c) {
        if (c >= '0' && c <= '9') return (uint8) (c - '0');
        if (c >= 'a' && c <= 'f') return (uint8) (c - 'a' + 10);
        if (c >= 'A' && c <= 'F') return (uint8) (c - 'A' + 10);
        return 0;
    }

    public class Keypair : Object {
        private uint8[] _secret_key;
        public uint8[] public_key_bytes;
        public string public_key { get; private set; }

        private Keypair () {
        }

        public static Keypair generate () {
            var kp = new Keypair ();
            kp._secret_key = new uint8[32];
            unowned Secp256k1.Context ctx = get_context ();

            do {
                fill_random (kp._secret_key);
            } while (ctx.ec_seckey_verify (kp._secret_key) != 1);

            kp.derive_public_key ();
            return kp;
        }

        public static Keypair from_secret_key (string hex) throws GLib.Error {
            var kp = new Keypair ();
            kp._secret_key = hex_decode (hex);

            if (kp._secret_key.length != 32) {
                throw new IOError.INVALID_DATA ("Secret key must be 32 bytes (64 hex chars)");
            }

            unowned Secp256k1.Context ctx = get_context ();
            if (ctx.ec_seckey_verify (kp._secret_key) != 1) {
                throw new IOError.INVALID_DATA ("Invalid secret key");
            }

            kp.derive_public_key ();
            return kp;
        }

        private void derive_public_key () {
            unowned Secp256k1.Context ctx = get_context ();
            Secp256k1.Keypair secp_kp;
            ctx.keypair_create (out secp_kp, _secret_key);

            Secp256k1.XOnlyPubkey xonly;
            ctx.keypair_xonly_pub (out xonly, null, ref secp_kp);

            public_key_bytes = new uint8[32];
            ctx.xonly_pubkey_serialize (public_key_bytes, ref xonly);

            public_key = hex_encode (public_key_bytes);
        }

        public uint8[] sign (uint8[] msg32) {
            unowned Secp256k1.Context ctx = get_context ();
            Secp256k1.Keypair secp_kp;
            ctx.keypair_create (out secp_kp, _secret_key);

            var sig = new uint8[64];
            ctx.schnorrsig_sign32 (sig, msg32, ref secp_kp, null);
            return sig;
        }
    }

    public class Event : Object {
        public string id { get; set; default = ""; }
        public string pubkey { get; set; default = ""; }
        public int64 created_at { get; set; }
        public int kind { get; set; }
        public GenericArray<GenericArray<string>> tags { get; set; }
        public string content { get; set; default = ""; }
        public string sig { get; set; default = ""; }

        public Event (int kind, string content) {
            this.kind = kind;
            this.content = content;
            this.tags = new GenericArray<GenericArray<string>> ();
            this.created_at = new DateTime.now_utc ().to_unix ();
        }

        public void add_tag (string name, ...) {
            var tag = new GenericArray<string> ();
            tag.add (name);
            var args = va_list ();
            while (true) {
                string? val = args.arg<string?> ();
                if (val == null) {
                    break;
                }
                tag.add (val);
            }
            tags.add (tag);
        }

        private void serialize_tags (Json.Builder builder) {
            builder.begin_array ();
            for (uint i = 0; i < tags.length; i++) {
                builder.begin_array ();
                var tag = tags[i];
                for (uint j = 0; j < tag.length; j++) {
                    builder.add_string_value (tag[j]);
                }
                builder.end_array ();
            }
            builder.end_array ();
        }

        public void compute_id (string pubkey) {
            var builder = new Json.Builder ();
            builder.begin_array ();
            builder.add_int_value (0);
            builder.add_string_value (pubkey);
            builder.add_int_value (created_at);
            builder.add_int_value (kind);
            serialize_tags (builder);
            builder.add_string_value (content);
            builder.end_array ();

            var gen = new Json.Generator ();
            gen.set_root (builder.get_root ());
            gen.set_pretty (false);
            var serialized = gen.to_data (null);

            var checksum = new Checksum (ChecksumType.SHA256);
            checksum.update ((uint8[]) serialized.to_utf8 (), serialized.length);

            uint8 hash_bytes[32];
            size_t hash_len = 32;
            checksum.get_digest (hash_bytes, ref hash_len);

            this.id = hex_encode (hash_bytes);
        }

        public void sign (Nostr.Keypair keypair) {
            this.pubkey = keypair.public_key;
            compute_id (this.pubkey);

            var id_bytes = hex_decode (this.id);
            var sig_bytes = keypair.sign (id_bytes);
            this.sig = hex_encode (sig_bytes);
        }

        public bool verify () {
            unowned Secp256k1.Context ctx = get_context ();

            var id_bytes = hex_decode (this.id);
            var sig_bytes = hex_decode (this.sig);
            var pubkey_bytes = hex_decode (this.pubkey);

            Secp256k1.XOnlyPubkey xonly;
            if (ctx.xonly_pubkey_parse (out xonly, pubkey_bytes) != 1) {
                return false;
            }

            return ctx.schnorrsig_verify (sig_bytes, id_bytes, ref xonly) == 1;
        }

        public string to_json () {
            var builder = new Json.Builder ();
            builder.begin_object ();

            builder.set_member_name ("id");
            builder.add_string_value (id);

            builder.set_member_name ("pubkey");
            builder.add_string_value (pubkey);

            builder.set_member_name ("created_at");
            builder.add_int_value (created_at);

            builder.set_member_name ("kind");
            builder.add_int_value (kind);

            builder.set_member_name ("tags");
            serialize_tags (builder);

            builder.set_member_name ("content");
            builder.add_string_value (content);

            builder.set_member_name ("sig");
            builder.add_string_value (sig);

            builder.end_object ();

            var gen = new Json.Generator ();
            gen.set_root (builder.get_root ());
            gen.set_pretty (false);
            return gen.to_data (null);
        }

        public static Event from_json (string json) throws GLib.Error {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            var obj = parser.get_root ().get_object ();

            var kind = (int) obj.get_int_member ("kind");
            var content = obj.get_string_member ("content");

            var ev = new Event (kind, content);

            var tags_node = obj.get_array_member ("tags");
            for (uint i = 0; i < tags_node.get_length (); i++) {
                var tag_arr = tags_node.get_array_element (i);
                var tag = new GenericArray<string> ();
                for (uint j = 0; j < tag_arr.get_length (); j++) {
                    tag.add (tag_arr.get_string_element (j));
                }
                ev.tags.add (tag);
            }

            ev.id = obj.get_string_member ("id");
            ev.pubkey = obj.get_string_member ("pubkey");
            ev.created_at = obj.get_int_member ("created_at");
            ev.sig = obj.get_string_member ("sig");

            return ev;
        }
    }
}
