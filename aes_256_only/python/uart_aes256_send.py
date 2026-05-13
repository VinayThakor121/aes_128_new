#!/usr/bin/env python3
"""
uart_aes256_send.py — PC-side UART utility for aes_256_only FPGA top.

Sends one 54-byte packet containing a 128-bit plaintext and 256-bit AES key.
The FPGA responds with three 18-byte frames:
  0x03 + original plaintext (16B) + XOR checksum
  0x13 + AES-256 ciphertext  (16B) + XOR checksum
  0x23 + AES-256 decrypted   (16B) + XOR checksum

Total response: 54 bytes.

Usage:
    python uart_aes256_send.py [--port /dev/ttyUSB0] [--baud 115200]
                               [--plaintext HEX] [--key256 HEX]

Requires: pip install pyserial
"""
import argparse
import sys

DEFAULT_PT   = bytes.fromhex("00112233445566778899aabbccddeeff")
DEFAULT_K256 = bytes.fromhex(
    "000102030405060708090a0b0c0d0e0f"
    "101112131415161718191a1b1c1d1e1f"
)

# Response frame IDs
FRAME_ORIG_PT = 0x03   # original plaintext echoed back
FRAME_CT      = 0x13   # AES-256 encrypted ciphertext
FRAME_DEC_PT  = 0x23   # AES-256 decrypted plaintext (should match original)


def build_packet(plaintext: bytes, key256: bytes) -> bytes:
    if len(plaintext) != 16 or len(key256) != 32:
        raise ValueError("plaintext=16B and key256=32B required")
    payload = plaintext + key256           # 48 bytes
    chk = 0
    for b in payload:
        chk ^= b
    pkt = bytes([0xAA, 0x03, 0x00, 0x30]) + payload + bytes([chk, 0x55])
    assert len(pkt) == 54
    return pkt


def _parse_frame(data: bytes, offset: int, expected_id: int) -> bytes:
    """Parse one 18-byte response frame: [ID][16 data bytes][checksum]."""
    if data[offset] != expected_id:
        raise ValueError(
            f"Frame at offset {offset}: expected ID 0x{expected_id:02X}, "
            f"got 0x{data[offset]:02X}"
        )
    payload = data[offset + 1 : offset + 17]
    chk = 0
    for b in payload:
        chk ^= b
    if chk != data[offset + 17]:
        raise ValueError(
            f"Frame at offset {offset}: checksum mismatch "
            f"(calc=0x{chk:02X}, got=0x{data[offset+17]:02X})"
        )
    return bytes(payload)


def parse_response(data: bytes) -> dict:
    """Parse 54-byte response: orig_pt frame, ct frame, dec_pt frame."""
    if len(data) != 54:
        raise ValueError(f"Expected 54 bytes, got {len(data)}")
    orig_pt = _parse_frame(data,  0, FRAME_ORIG_PT)
    ct      = _parse_frame(data, 18, FRAME_CT)
    dec_pt  = _parse_frame(data, 36, FRAME_DEC_PT)
    return {FRAME_ORIG_PT: orig_pt, FRAME_CT: ct, FRAME_DEC_PT: dec_pt}


def run(args):
    try:
        import serial
    except ImportError:
        print("Install pyserial: pip install pyserial")
        sys.exit(1)

    pt   = bytes.fromhex(args.plaintext.replace(" ", ""))
    k256 = bytes.fromhex(args.key256.replace(" ", ""))

    pkt = build_packet(pt, k256)
    ser = serial.Serial(args.port, args.baud, timeout=5.0)
    try:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        ser.write(pkt)
        ser.flush()
        resp = ser.read(54)   # 3 frames × 18 bytes each
    finally:
        ser.close()

    parsed = parse_response(resp)

    print()
    print("## AES-256 UART TEST")
    print()
    print("Input Plaintext:")
    print(parsed[FRAME_ORIG_PT].hex().upper())
    print()
    print("Encryption Key:")
    print(k256.hex().upper())
    print()
    print("Encrypted Ciphertext:")
    print(parsed[FRAME_CT].hex().upper())
    print()
    print("Decrypted Plaintext:")
    print(parsed[FRAME_DEC_PT].hex().upper())
    print()

    match = (parsed[FRAME_DEC_PT] == pt)
    print("RESULT:")
    if match:
        print("PASS - Retrieved plaintext matches original plaintext")
    else:
        print("FAIL - Retrieved plaintext does NOT match original plaintext")
    print()


def main():
    ap = argparse.ArgumentParser(description="UART utility for aes_256_only FPGA top")
    ap.add_argument("--port",      default="/dev/ttyUSB0")
    ap.add_argument("--baud",      type=int, default=115200)
    ap.add_argument("--plaintext", default=DEFAULT_PT.hex())
    ap.add_argument("--key256",    default=DEFAULT_K256.hex())
    run(ap.parse_args())


if __name__ == "__main__":
    main()
