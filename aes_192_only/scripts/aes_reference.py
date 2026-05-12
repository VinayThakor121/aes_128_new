#!/usr/bin/env python3
"""
aes_reference.py — Standard AES reference for comparison and testing.

Computes standard AES-128/192/256 encryption and decryption using the
pycryptodome library, and documents how Modified AES V2 results differ.

Usage:
    python aes_reference.py [--plaintext HEX] [--key128 HEX] \
                            [--key192 HEX] [--key256 HEX]

Requires:  pip install pycryptodome
"""

import argparse
import sys

# ---------------------------------------------------------------------------
# Default NIST FIPS-197 Appendix C test vectors
# ---------------------------------------------------------------------------
DEFAULT_PT   = "00112233445566778899aabbccddeeff"
DEFAULT_K128 = "000102030405060708090a0b0c0d0e0f"
DEFAULT_K192 = "000102030405060708090a0b0c0d0e0f1011121314151617"
DEFAULT_K256 = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"

# Known Modified AES V2 ciphertext values (from simulation; differ from std)
MOD_V2_CT = {
    128: "135c5762f9d74dc27cde153393eb1a31",
    192: "1c556f67dda70687553f924d7c153246",
    256: "0a6aff44e685399d3bbf12db93d70e09",
}


def compute_standard_aes(plaintext: bytes, key: bytes) -> tuple:
    """Return (ciphertext, recovered_plaintext) for standard AES-ECB."""
    try:
        from Crypto.Cipher import AES
    except ImportError:
        print("ERROR: pycryptodome not installed.  Run: pip install pycryptodome")
        sys.exit(1)

    ct = AES.new(key, AES.MODE_ECB).encrypt(plaintext)
    rt = AES.new(key, AES.MODE_ECB).decrypt(ct)
    return ct, rt


def run(args):
    pt   = bytes.fromhex(args.plaintext)
    k128 = bytes.fromhex(args.key128)
    k192 = bytes.fromhex(args.key192)
    k256 = bytes.fromhex(args.key256)

    print("=" * 66)
    print("  Standard AES Reference (FIPS-197)")
    print("=" * 66)
    print(f"  Plaintext : {pt.hex()}")
    print(f"  Key-128   : {k128.hex()}")
    print(f"  Key-192   : {k192.hex()}")
    print(f"  Key-256   : {k256.hex()}")

    results = []
    for key_size, key in [(128, k128), (192, k192), (256, k256)]:
        ct, rt = compute_standard_aes(pt, key)
        results.append((key_size, ct, rt))

    print("\n--- Standard AES Results ---")
    for ks, ct, rt in results:
        rt_ok = "✓" if rt == pt else "✗ FAIL"
        print(f"\n  AES-{ks}:")
        print(f"    Ciphertext (std) : {ct.hex()}")
        print(f"    Round-trip       : {rt.hex()}  {rt_ok}")

    print("\n--- Modified AES V2 vs Standard AES ---")
    print("  (Modified V2 ciphertext values from FPGA simulation)")
    for ks, ct_std, _ in results:
        ct_mod = MOD_V2_CT[ks]
        differs = ct_std.hex() != ct_mod
        marker  = "DIFFERS ✓" if differs else "SAME ✗ (mod may be inactive)"
        print(f"\n  AES-{ks}:")
        print(f"    Standard     : {ct_std.hex()}")
        print(f"    Modified V2  : {ct_mod}")
        print(f"    Comparison   : {marker}")

    print("\n--- NIST FIPS-197 Expected Ciphertexts (standard AES) ---")
    nist_ct = {
        128: "69c4e0d86a7b0430d8cdb78070b4c55a",
        192: "dda97ca4864cdfe06eaf70a0ec0d7191",
        256: "8ea2b7ca516745bfeafc49904b496089",
    }
    for ks, ct_std, _ in results:
        match = "PASS ✓" if ct_std.hex() == nist_ct[ks] else "FAIL ✗"
        print(f"  AES-{ks}: {match}  ({ct_std.hex()})")

    print("\n" + "=" * 66)
    print("  Note: The FPGA implements Modified AES V2 (Abikoye et al.).")
    print("  Its ciphertexts differ from standard AES by design.")
    print("  Round-trip correctness (enc→dec = plaintext) is the key test.")
    print("=" * 66)


def main():
    parser = argparse.ArgumentParser(
        description="Compute standard AES reference values for FPGA comparison."
    )
    parser.add_argument("--plaintext", default=DEFAULT_PT,
                        help="128-bit plaintext (32 hex chars)")
    parser.add_argument("--key128",   default=DEFAULT_K128,
                        help="128-bit key (32 hex chars)")
    parser.add_argument("--key192",   default=DEFAULT_K192,
                        help="192-bit key (48 hex chars)")
    parser.add_argument("--key256",   default=DEFAULT_K256,
                        help="256-bit key (64 hex chars)")
    run(parser.parse_args())


if __name__ == "__main__":
    main()
