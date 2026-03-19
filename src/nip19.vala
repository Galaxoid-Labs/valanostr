namespace Nostr {

    // ── Bech32 primitives ───────────────────────────────────────

    private const string BECH32_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

    private static uint32 bech32_polymod (uint8[] values) {
        uint32 chk = 1;
        for (int i = 0; i < values.length; i++) {
            uint32 b = chk >> 25;
            chk = ((chk & 0x1ffffff) << 5) ^ values[i];
            if ((b & 1) != 0) chk ^= 0x3b6a57b2;
            if ((b & 2) != 0) chk ^= 0x26508e6d;
            if ((b & 4) != 0) chk ^= 0x1ea119fa;
            if ((b & 8) != 0) chk ^= 0x3d4233dd;
            if ((b & 16) != 0) chk ^= 0x2a1462b3;
        }
        return chk;
    }

    private static uint8[] bech32_hrp_expand (string hrp) {
        int len = hrp.length;
        var result = new uint8[len * 2 + 1];
        for (int i = 0; i < len; i++) {
            result[i] = (uint8) (hrp[i] >> 5);
        }
        result[len] = 0;
        for (int i = 0; i < len; i++) {
            result[len + 1 + i] = (uint8) (hrp[i] & 31);
        }
        return result;
    }

    private static uint8[] bech32_create_checksum (string hrp, uint8[] data5) {
        var hrp_exp = bech32_hrp_expand (hrp);
        int total = hrp_exp.length + data5.length + 6;
        var values = new uint8[total];
        for (int i = 0; i < hrp_exp.length; i++) {
            values[i] = hrp_exp[i];
        }
        for (int i = 0; i < data5.length; i++) {
            values[hrp_exp.length + i] = data5[i];
        }
        uint32 polymod = bech32_polymod (values) ^ 1;
        var checksum = new uint8[6];
        for (int i = 0; i < 6; i++) {
            checksum[i] = (uint8) ((polymod >> (5 * (5 - i))) & 31);
        }
        return checksum;
    }

    private static bool bech32_verify_checksum (string hrp, uint8[] data5) {
        var hrp_exp = bech32_hrp_expand (hrp);
        int total = hrp_exp.length + data5.length;
        var values = new uint8[total];
        for (int i = 0; i < hrp_exp.length; i++) {
            values[i] = hrp_exp[i];
        }
        for (int i = 0; i < data5.length; i++) {
            values[hrp_exp.length + i] = data5[i];
        }
        return bech32_polymod (values) == 1;
    }

    private static uint8[] convert_bits_8to5 (uint8[] data) {
        int out_len = (data.length * 8 + 4) / 5;
        var result = new uint8[out_len];
        int acc = 0;
        int bits = 0;
        int idx = 0;
        for (int i = 0; i < data.length; i++) {
            acc = (acc << 8) | data[i];
            bits += 8;
            while (bits >= 5) {
                bits -= 5;
                result[idx++] = (uint8) ((acc >> bits) & 31);
            }
        }
        if (bits > 0) {
            result[idx++] = (uint8) ((acc << (5 - bits)) & 31);
        }
        return result;
    }

    private static uint8[] convert_bits_5to8 (uint8[] data) throws GLib.Error {
        int out_len = data.length * 5 / 8;
        var result = new uint8[out_len];
        int acc = 0;
        int bits = 0;
        int idx = 0;
        for (int i = 0; i < data.length; i++) {
            if (data[i] > 31) {
                throw new IOError.INVALID_DATA ("Invalid 5-bit value in bech32 data");
            }
            acc = (acc << 5) | data[i];
            bits += 5;
            while (bits >= 8) {
                bits -= 8;
                result[idx++] = (uint8) ((acc >> bits) & 0xff);
            }
        }
        if (bits >= 5) {
            throw new IOError.INVALID_DATA ("Excess padding in bech32 data");
        }
        if (bits > 0 && ((acc << (8 - bits)) & 0xff) != 0) {
            throw new IOError.INVALID_DATA ("Non-zero padding in bech32 data");
        }
        return result;
    }

    // ── Bech32 public API ───────────────────────────────────────

    public static string bech32_encode (string hrp, uint8[] data) {
        var data5 = convert_bits_8to5 (data);
        var checksum = bech32_create_checksum (hrp, data5);
        var builder = new StringBuilder.sized (hrp.length + 1 + data5.length + 6);
        builder.append (hrp);
        builder.append_c ('1');
        for (int i = 0; i < data5.length; i++) {
            builder.append_c (BECH32_CHARSET[data5[i]]);
        }
        for (int i = 0; i < 6; i++) {
            builder.append_c (BECH32_CHARSET[checksum[i]]);
        }
        return builder.str;
    }

    public static uint8[] bech32_decode (string bech32, out string hrp) throws GLib.Error {
        if (bech32.length > 5000) {
            throw new IOError.INVALID_DATA ("Bech32 string exceeds 5000 character limit");
        }

        var str = bech32.down ();

        int sep = -1;
        for (int i = str.length - 1; i >= 0; i--) {
            if (str[i] == '1') {
                sep = i;
                break;
            }
        }
        if (sep < 1 || sep + 7 > str.length) {
            throw new IOError.INVALID_DATA ("Invalid bech32 string");
        }

        hrp = str.substring (0, sep);

        int data_len = str.length - sep - 1;
        var data5 = new uint8[data_len];
        for (int i = 0; i < data_len; i++) {
            int pos = BECH32_CHARSET.index_of_char (str[sep + 1 + i]);
            if (pos < 0) {
                throw new IOError.INVALID_DATA ("Invalid bech32 character");
            }
            data5[i] = (uint8) pos;
        }

        if (!bech32_verify_checksum (hrp, data5)) {
            throw new IOError.INVALID_DATA ("Invalid bech32 checksum");
        }

        var stripped = new uint8[data5.length - 6];
        for (int i = 0; i < stripped.length; i++) {
            stripped[i] = data5[i];
        }

        return convert_bits_5to8 (stripped);
    }

    // ── NIP-19 bare key encoding ────────────────────────────────

    public static string encode_npub (string pubkey_hex) {
        return bech32_encode ("npub", hex_decode (pubkey_hex));
    }

    public static string encode_nsec (string seckey_hex) {
        return bech32_encode ("nsec", hex_decode (seckey_hex));
    }

    public static string encode_note (string event_id_hex) {
        return bech32_encode ("note", hex_decode (event_id_hex));
    }

    public static string decode_npub (string bech32) throws GLib.Error {
        string hrp;
        var data = bech32_decode (bech32, out hrp);
        if (hrp != "npub") {
            throw new IOError.INVALID_DATA ("Expected npub prefix, got %s", hrp);
        }
        if (data.length != 32) {
            throw new IOError.INVALID_DATA ("npub data must be 32 bytes");
        }
        return hex_encode (data);
    }

    public static string decode_nsec (string bech32) throws GLib.Error {
        string hrp;
        var data = bech32_decode (bech32, out hrp);
        if (hrp != "nsec") {
            throw new IOError.INVALID_DATA ("Expected nsec prefix, got %s", hrp);
        }
        if (data.length != 32) {
            throw new IOError.INVALID_DATA ("nsec data must be 32 bytes");
        }
        return hex_encode (data);
    }

    public static string decode_note (string bech32) throws GLib.Error {
        string hrp;
        var data = bech32_decode (bech32, out hrp);
        if (hrp != "note") {
            throw new IOError.INVALID_DATA ("Expected note prefix, got %s", hrp);
        }
        if (data.length != 32) {
            throw new IOError.INVALID_DATA ("note data must be 32 bytes");
        }
        return hex_encode (data);
    }

    // ── NIP-19 TLV result types ─────────────────────────────────

    public class Nip19Profile : Object {
        public string pubkey;
        public GenericArray<string> relays;

        public Nip19Profile () {
            pubkey = "";
            relays = new GenericArray<string> ();
        }
    }

    public class Nip19Event : Object {
        public string id;
        public GenericArray<string> relays;
        public string author;
        public int kind;

        public Nip19Event () {
            id = "";
            relays = new GenericArray<string> ();
            author = "";
            kind = -1;
        }
    }

    public class Nip19Addr : Object {
        public string identifier;
        public string pubkey;
        public int kind;
        public GenericArray<string> relays;

        public Nip19Addr () {
            identifier = "";
            pubkey = "";
            kind = 0;
            relays = new GenericArray<string> ();
        }
    }

    // ── TLV helpers ─────────────────────────────────────────────

    private static void tlv_append (ByteArray buf, uint8 type_id, uint8[] value) {
        uint8[] header = { type_id, (uint8) value.length };
        buf.append (header);
        buf.append (value);
    }

    private static string tlv_read_string (uint8[] data, int offset, int len) {
        var sb = new StringBuilder.sized (len);
        for (int i = 0; i < len; i++) {
            sb.append_c ((char) data[offset + i]);
        }
        return sb.str;
    }

    private static string tlv_read_hex (uint8[] data, int offset, int len) {
        var bytes = new uint8[len];
        for (int i = 0; i < len; i++) {
            bytes[i] = data[offset + i];
        }
        return hex_encode (bytes);
    }

    private static int tlv_read_uint32_be (uint8[] data, int offset) {
        return ((int) data[offset] << 24)
             | ((int) data[offset + 1] << 16)
             | ((int) data[offset + 2] << 8)
             | (int) data[offset + 3];
    }

    // ── NIP-19 TLV encoding ─────────────────────────────────────

    public static string encode_nprofile (string pubkey_hex, string[]? relays = null) {
        var buf = new ByteArray ();
        tlv_append (buf, 0, hex_decode (pubkey_hex));
        if (relays != null) {
            foreach (unowned string relay in relays) {
                tlv_append (buf, 1, relay.data);
            }
        }
        return bech32_encode ("nprofile", buf.data);
    }

    public static string encode_nevent (string event_id_hex, string[]? relays = null, string? author_hex = null, int kind = -1) {
        var buf = new ByteArray ();
        tlv_append (buf, 0, hex_decode (event_id_hex));
        if (relays != null) {
            foreach (unowned string relay in relays) {
                tlv_append (buf, 1, relay.data);
            }
        }
        if (author_hex != null) {
            tlv_append (buf, 2, hex_decode (author_hex));
        }
        if (kind >= 0) {
            uint8[] kind_bytes = {
                (uint8) ((kind >> 24) & 0xff),
                (uint8) ((kind >> 16) & 0xff),
                (uint8) ((kind >> 8) & 0xff),
                (uint8) (kind & 0xff)
            };
            tlv_append (buf, 3, kind_bytes);
        }
        return bech32_encode ("nevent", buf.data);
    }

    public static string encode_naddr (string identifier, string pubkey_hex, int kind, string[]? relays = null) {
        var buf = new ByteArray ();
        tlv_append (buf, 0, identifier.data);
        if (relays != null) {
            foreach (unowned string relay in relays) {
                tlv_append (buf, 1, relay.data);
            }
        }
        tlv_append (buf, 2, hex_decode (pubkey_hex));
        uint8[] kind_bytes = {
            (uint8) ((kind >> 24) & 0xff),
            (uint8) ((kind >> 16) & 0xff),
            (uint8) ((kind >> 8) & 0xff),
            (uint8) (kind & 0xff)
        };
        tlv_append (buf, 3, kind_bytes);
        return bech32_encode ("naddr", buf.data);
    }

    // ── NIP-19 TLV decoding ─────────────────────────────────────

    public static Nip19Profile decode_nprofile (string bech32) throws GLib.Error {
        string hrp;
        var data = bech32_decode (bech32, out hrp);
        if (hrp != "nprofile") {
            throw new IOError.INVALID_DATA ("Expected nprofile prefix, got %s", hrp);
        }

        var result = new Nip19Profile ();
        int offset = 0;
        while (offset < data.length) {
            if (offset + 2 > data.length) {
                throw new IOError.INVALID_DATA ("Truncated TLV data");
            }
            uint8 t = data[offset];
            int l = data[offset + 1];
            if (offset + 2 + l > data.length) {
                throw new IOError.INVALID_DATA ("TLV value exceeds data length");
            }
            switch (t) {
            case 0:
                if (l != 32) {
                    throw new IOError.INVALID_DATA ("nprofile pubkey must be 32 bytes");
                }
                result.pubkey = tlv_read_hex (data, offset + 2, l);
                break;
            case 1:
                result.relays.add (tlv_read_string (data, offset + 2, l));
                break;
            default:
                break;
            }
            offset += 2 + l;
        }
        return result;
    }

    public static Nip19Event decode_nevent (string bech32) throws GLib.Error {
        string hrp;
        var data = bech32_decode (bech32, out hrp);
        if (hrp != "nevent") {
            throw new IOError.INVALID_DATA ("Expected nevent prefix, got %s", hrp);
        }

        var result = new Nip19Event ();
        int offset = 0;
        while (offset < data.length) {
            if (offset + 2 > data.length) {
                throw new IOError.INVALID_DATA ("Truncated TLV data");
            }
            uint8 t = data[offset];
            int l = data[offset + 1];
            if (offset + 2 + l > data.length) {
                throw new IOError.INVALID_DATA ("TLV value exceeds data length");
            }
            switch (t) {
            case 0:
                if (l != 32) {
                    throw new IOError.INVALID_DATA ("nevent id must be 32 bytes");
                }
                result.id = tlv_read_hex (data, offset + 2, l);
                break;
            case 1:
                result.relays.add (tlv_read_string (data, offset + 2, l));
                break;
            case 2:
                if (l != 32) {
                    throw new IOError.INVALID_DATA ("nevent author must be 32 bytes");
                }
                result.author = tlv_read_hex (data, offset + 2, l);
                break;
            case 3:
                if (l != 4) {
                    throw new IOError.INVALID_DATA ("nevent kind must be 4 bytes");
                }
                result.kind = tlv_read_uint32_be (data, offset + 2);
                break;
            default:
                break;
            }
            offset += 2 + l;
        }
        return result;
    }

    public static Nip19Addr decode_naddr (string bech32) throws GLib.Error {
        string hrp;
        var data = bech32_decode (bech32, out hrp);
        if (hrp != "naddr") {
            throw new IOError.INVALID_DATA ("Expected naddr prefix, got %s", hrp);
        }

        var result = new Nip19Addr ();
        int offset = 0;
        while (offset < data.length) {
            if (offset + 2 > data.length) {
                throw new IOError.INVALID_DATA ("Truncated TLV data");
            }
            uint8 t = data[offset];
            int l = data[offset + 1];
            if (offset + 2 + l > data.length) {
                throw new IOError.INVALID_DATA ("TLV value exceeds data length");
            }
            switch (t) {
            case 0:
                result.identifier = tlv_read_string (data, offset + 2, l);
                break;
            case 1:
                result.relays.add (tlv_read_string (data, offset + 2, l));
                break;
            case 2:
                if (l != 32) {
                    throw new IOError.INVALID_DATA ("naddr pubkey must be 32 bytes");
                }
                result.pubkey = tlv_read_hex (data, offset + 2, l);
                break;
            case 3:
                if (l != 4) {
                    throw new IOError.INVALID_DATA ("naddr kind must be 4 bytes");
                }
                result.kind = tlv_read_uint32_be (data, offset + 2);
                break;
            default:
                break;
            }
            offset += 2 + l;
        }
        return result;
    }
}
