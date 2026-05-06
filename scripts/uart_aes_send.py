#!/usr/bin/env python3
"""
uart_aes_send.py — PC-side script for UART ↔ Modified AES V2 FPGA communication.

Usage:
    python uart_aes_send.py [options]

Options:
    --port PORT       Serial port (default: auto-detect or /dev/ttyUSB0 / COM3)
    --baud BAUD       Baud rate (default: 115200)
    --plaintext HEX   128-bit plaintext as 32 hex chars (default: NIST vector)
    --key128 HEX      128-bit key as 32 hex chars
    --key192 HEX      192-bit key as 48 hex chars
    --key256 HEX      256-bit key as 64 hex chars
    --verify          Cross-check decrypted outputs against plaintext

Packet format (94 bytes, sent to FPGA):
    [0xAA][0x01][0x00][0x58]
    [plaintext 16B MSB-first]
    [key128 16B MSB-first]
    [key192 24B MSB-first]
    [key256 32B MSB-first]
    [XOR checksum of payload]
    [0x55]

Response format (108 bytes, 6 × 18-byte frames):
    Frame: [RESULT_ID][data 16B MSB-first][XOR checksum]
    IDs:   0x11=CT128, 0x12=CT192, 0x13=CT256,
           0x21=PT128, 0x22=PT192, 0x23=PT256

Requires:
    pip install pyserial
    pip install pycryptodome  (optional, for --verify)
"""

import sys
import argparse
import struct

# ---------------------------------------------------------------------------
# Default NIST FIPS-197 Appendix C test vectors
# ---------------------------------------------------------------------------
DEFAULT_PT   = bytes.fromhex("00112233445566778899aabbccddeeff")
DEFAULT_K128 = bytes.fromhex("000102030405060708090a0b0c0d0e0f")
DEFAULT_K192 = bytes.fromhex("000102030405060708090a0b0c0d0e0f1011121314151617")
DEFAULT_K256 = bytes.fromhex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")

RESULT_NAMES = {
    0x11: "AES-128 ciphertext",
    0x12: "AES-192 ciphertext",
    0x13: "AES-256 ciphertext",
    0x21: "AES-128 decrypted",
    0x22: "AES-192 decrypted",
    0x23: "AES-256 decrypted",
}
RESULT_ORDER = [0x11, 0x12, 0x13, 0x21, 0x22, 0x23]

# ---------------------------------------------------------------------------
# Packet building
# ---------------------------------------------------------------------------

def build_packet(plaintext: bytes, key128: bytes,
                 key192: bytes, key256: bytes) -> bytes:
    """Construct the 94-byte input packet."""
    if len(plaintext) != 16:
        raise ValueError("plaintext must be 16 bytes")
    if len(key128) != 16:
        raise ValueError("key128 must be 16 bytes")
    if len(key192) != 24:
        raise ValueError("key192 must be 24 bytes")
    if len(key256) != 32:
        raise ValueError("key256 must be 32 bytes")

    payload = plaintext + key128 + key192 + key256   # 88 bytes
    checksum = 0
    for b in payload:
        checksum ^= b

    packet = (
        bytes([0xAA, 0x01, 0x00, 0x58]) +
        payload +
        bytes([checksum, 0x55])
    )
    assert len(packet) == 94, f"Packet length error: {len(packet)}"
    return packet


# ---------------------------------------------------------------------------
# Response parsing
# ---------------------------------------------------------------------------

def parse_response(data: bytes) -> dict:
    """
    Parse 108 bytes (6 × 18-byte frames) into a dict of RESULT_ID → bytes.

    Raises ValueError if any frame has a bad checksum or unexpected ID.
    """
    if len(data) != 108:
        raise ValueError(f"Expected 108 response bytes, got {len(data)}")

    results = {}
    for i, expected_id in enumerate(RESULT_ORDER):
        base = i * 18
        frame_id = data[base]
        frame_data = data[base + 1: base + 17]
        frame_chk  = data[base + 17]

        if frame_id != expected_id:
            raise ValueError(
                f"Frame {i}: expected ID 0x{expected_id:02X}, "
                f"got 0x{frame_id:02X}"
            )

        calc_chk = 0
        for b in frame_data:
            calc_chk ^= b
        if calc_chk != frame_chk:
            raise ValueError(
                f"Frame {i} (ID 0x{frame_id:02X}): "
                f"checksum error — calc=0x{calc_chk:02X} recv=0x{frame_chk:02X}"
            )

        results[frame_id] = frame_data

    return results


# ---------------------------------------------------------------------------
# Optional verification against standard AES (pycryptodome)
# ---------------------------------------------------------------------------

def verify_with_reference(plaintext, key128, key192, key256, results):
    """
    Compare FPGA results against standard AES from pycryptodome.

    Note: Modified AES V2 ciphertexts WILL differ from standard AES.
    This function only verifies round-trip (decrypted == plaintext).
    """
    try:
        from Crypto.Cipher import AES as _AES
    except ImportError:
        print("\n[verify] pycryptodome not installed — skipping reference check.")
        print("         Install with: pip install pycryptodome")
        return

    print("\n--- Reference verification (pycryptodome standard AES) ---")
    for key, rid_ct, rid_pt, name in [
        (key128, 0x11, 0x21, "AES-128"),
        (key192, 0x12, 0x22, "AES-192"),
        (key256, 0x13, 0x23, "AES-256"),
    ]:
        std_ct = _AES.new(key, _AES.MODE_ECB).encrypt(plaintext)
        fpga_ct = results[rid_ct]
        fpga_pt = results[rid_pt]

        print(f"  {name}:")
        print(f"    Std  ciphertext : {std_ct.hex()}")
        print(f"    FPGA ciphertext : {fpga_ct.hex()}")
        if fpga_ct != std_ct:
            print(f"    Ciphertexts differ (Modified V2 is active) ✓")
        else:
            print(f"    WARNING: ciphertexts match standard AES "
                  f"— V2 modification may be inactive!")

        if fpga_pt == plaintext:
            print(f"    Round-trip (decrypt) : PASS ✓")
        else:
            print(f"    Round-trip (decrypt) : FAIL ✗")
            print(f"    Expected : {plaintext.hex()}")
            print(f"    Got      : {fpga_pt.hex()}")


# ---------------------------------------------------------------------------
# Serial communication
# ---------------------------------------------------------------------------

def run(args):
    try:
        import serial
    except ImportError:
        print("ERROR: pyserial not installed.  Run: pip install pyserial")
        sys.exit(1)

    # Parse hex inputs
    try:
        plaintext = bytes.fromhex(args.plaintext.replace(" ", ""))
        key128    = bytes.fromhex(args.key128.replace(" ", ""))
        key192    = bytes.fromhex(args.key192.replace(" ", ""))
        key256    = bytes.fromhex(args.key256.replace(" ", ""))
    except ValueError as e:
        print(f"ERROR parsing hex input: {e}")
        sys.exit(1)

    print("==============================================")
    print("  UART ↔ Modified AES V2 Communication")
    print("==============================================")
    print(f"  Port      : {args.port}")
    print(f"  Baud      : {args.baud}")
    print(f"  Plaintext : {plaintext.hex()}")
    print(f"  Key128    : {key128.hex()}")
    print(f"  Key192    : {key192.hex()}")
    print(f"  Key256    : {key256.hex()}")

    # Build packet
    packet = build_packet(plaintext, key128, key192, key256)
    print(f"\n  Packet ({len(packet)} bytes): {packet.hex()}")

    # Open serial port
    try:
        ser = serial.Serial(
            port=args.port,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=5.0
        )
    except serial.SerialException as e:
        print(f"ERROR opening port: {e}")
        sys.exit(1)

    try:
        # Flush any stale data
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        # Send packet
        print(f"\n[TX] Sending {len(packet)}-byte packet...")
        ser.write(packet)
        ser.flush()

        # Read response
        print(f"[RX] Waiting for 108-byte response...")
        response = ser.read(108)
        if len(response) != 108:
            print(f"ERROR: expected 108 bytes, received {len(response)}")
            sys.exit(1)

        print(f"[RX] {len(response)} bytes received.")

    finally:
        ser.close()

    # Parse and display
    try:
        results = parse_response(response)
    except ValueError as e:
        print(f"ERROR parsing response: {e}")
        print(f"Raw response: {response.hex()}")
        sys.exit(1)

    print("\n==============================================")
    print("  Results")
    print("==============================================")
    for rid in RESULT_ORDER:
        print(f"  [{hex(rid)}] {RESULT_NAMES[rid]:25s} : {results[rid].hex()}")

    if args.verify:
        verify_with_reference(plaintext, key128, key192, key256, results)

    print("\n  All frames decoded successfully.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Send AES input to FPGA via UART and receive results."
    )
    parser.add_argument("--port",
                        default="/dev/ttyUSB0",
                        help="Serial port (default: /dev/ttyUSB0)")
    parser.add_argument("--baud",
                        type=int,
                        default=115200,
                        help="Baud rate (default: 115200)")
    parser.add_argument("--plaintext",
                        default=DEFAULT_PT.hex(),
                        help="128-bit plaintext (32 hex chars)")
    parser.add_argument("--key128",
                        default=DEFAULT_K128.hex(),
                        help="128-bit key (32 hex chars)")
    parser.add_argument("--key192",
                        default=DEFAULT_K192.hex(),
                        help="192-bit key (48 hex chars)")
    parser.add_argument("--key256",
                        default=DEFAULT_K256.hex(),
                        help="256-bit key (64 hex chars)")
    parser.add_argument("--verify",
                        action="store_true",
                        help="Cross-check against pycryptodome reference AES")

    args = parser.parse_args()
    run(args)


if __name__ == "__main__":
    main()
