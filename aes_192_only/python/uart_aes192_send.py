#!/usr/bin/env python3
import argparse
import sys

DEFAULT_PT   = bytes.fromhex("00112233445566778899aabbccddeeff")
DEFAULT_K192 = bytes.fromhex("000102030405060708090a0b0c0d0e0f1011121314151617")

# Response frame IDs
FRAME_ORIG_PT = 0x02   # original plaintext echoed back
FRAME_CT      = 0x12   # encrypted ciphertext
FRAME_DEC_PT  = 0x22   # decrypted plaintext (should match original)


def build_packet(plaintext: bytes, key192: bytes) -> bytes:
    if len(plaintext) != 16 or len(key192) != 24:
        raise ValueError("plaintext=16B and key192=24B required")
    payload = plaintext + key192
    chk = 0
    for b in payload:
        chk ^= b
    pkt = bytes([0xAA, 0x02, 0x00, 0x28]) + payload + bytes([chk, 0x55])
    assert len(pkt) == 46
    return pkt


def _parse_frame(data: bytes, offset: int, expected_id: int) -> bytes:
    """Parse one 18-byte response frame: [ID][16 data bytes][checksum]."""
    if data[offset] != expected_id:
        raise ValueError(
            f"Frame at offset {offset}: expected ID 0x{expected_id:02X}, got 0x{data[offset]:02X}"
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

    pt = bytes.fromhex(args.plaintext.replace(" ", ""))
    k192 = bytes.fromhex(args.key192.replace(" ", ""))

    pkt = build_packet(pt, k192)
    ser = serial.Serial(args.port, args.baud, timeout=5.0)
    try:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        ser.write(pkt)
        ser.flush()
        resp = ser.read(54)   # 3 frames x 18 bytes each
    finally:
        ser.close()

    parsed = parse_response(resp)

    print()
    print("## AES-192 UART TEST")
    print()
    print("Input Plaintext:")
    print(parsed[FRAME_ORIG_PT].hex().upper())
    print()
    print("Encryption Key:")
    print(k192.hex().upper())
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
    ap = argparse.ArgumentParser(description="UART utility for aes_192_only FPGA top")
    ap.add_argument("--port", default="/dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--plaintext", default=DEFAULT_PT.hex())
    ap.add_argument("--key192", default=DEFAULT_K192.hex())
    run(ap.parse_args())


if __name__ == "__main__":
    main()
