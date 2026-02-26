[CCode (cheader_filename = "secp256k1.h,secp256k1_extrakeys.h,secp256k1_schnorrsig.h")]
namespace Secp256k1 {
    [CCode (cname = "SECP256K1_CONTEXT_NONE")]
    public const uint CONTEXT_NONE;

    [CCode (cname = "secp256k1_pubkey", has_type_id = false)]
    public struct Pubkey {
        public uint8 data[64];
    }

    [CCode (cname = "secp256k1_xonly_pubkey", has_type_id = false)]
    public struct XOnlyPubkey {
        public uint8 data[64];
    }

    [CCode (cname = "secp256k1_keypair", has_type_id = false)]
    public struct Keypair {
        public uint8 data[96];
    }

    [Compact]
    [CCode (cname = "secp256k1_context", free_function = "secp256k1_context_destroy")]
    public class Context {
        [CCode (cname = "secp256k1_context_create")]
        public Context (uint flags = Secp256k1.CONTEXT_NONE);

        [CCode (cname = "secp256k1_context_randomize")]
        public int randomize ([CCode (array_length = false)] uint8[]? seed32);

        [CCode (cname = "secp256k1_ec_seckey_verify")]
        public int ec_seckey_verify ([CCode (array_length = false)] uint8[] seckey);

        [CCode (cname = "secp256k1_keypair_create")]
        public int keypair_create (out Secp256k1.Keypair keypair, [CCode (array_length = false)] uint8[] seckey);

        [CCode (cname = "secp256k1_keypair_xonly_pub")]
        public int keypair_xonly_pub (out Secp256k1.XOnlyPubkey pubkey, int* pk_parity, ref Secp256k1.Keypair keypair);

        [CCode (cname = "secp256k1_xonly_pubkey_serialize")]
        public int xonly_pubkey_serialize ([CCode (array_length = false)] uint8[] output32, ref Secp256k1.XOnlyPubkey pubkey);

        [CCode (cname = "secp256k1_xonly_pubkey_parse")]
        public int xonly_pubkey_parse (out Secp256k1.XOnlyPubkey pubkey, [CCode (array_length = false)] uint8[] input32);

        [CCode (cname = "secp256k1_schnorrsig_sign32")]
        public int schnorrsig_sign32 ([CCode (array_length = false)] uint8[] sig64, [CCode (array_length = false)] uint8[] msg32, ref Secp256k1.Keypair keypair, [CCode (array_length = false)] uint8[]? aux_rand32);

        [CCode (cname = "secp256k1_schnorrsig_verify")]
        public int schnorrsig_verify ([CCode (array_length = false)] uint8[] sig64, [CCode (array_length_type = "size_t")] uint8[] msg, ref Secp256k1.XOnlyPubkey pubkey);
    }
}
