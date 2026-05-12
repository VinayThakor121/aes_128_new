#!/usr/bin/env python3
import argparse
import sys

DEFAULT_PT   = bytes.fromhex("00112233445566778899aabbccddeeff")
DEFAULT_K192 = bytes.fromhex("000102030405060708090a0b0c0d0e0f1011121314151617")


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


def parse_response(data: bytes) -> dict:
    if len(data) != 36:
        raise ValueError(f"Expected 36 bytes, got {len(data)}")
    out = {}
    for i, rid in enumerate([0x12, 0x22]):
        base = i * 18
        if data[base] != rid:
            raise ValueError(f"Frame {i}: expected ID 0x{rid:02X}, got 0x{data[base]:02X}")
        frame = data[base+1:base+17]
        chk = 0
        for b in frame:
            chk ^= b
        if chk != data[base+17]:
            raise ValueError(f"Frame {i}: checksum mismatch")
        out[rid] = frame
    return out


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
        resp = ser.read(36)
    finally:
        ser.close()

    parsed = parse_response(resp)
    print(f"CT192: {parsed[0x12].hex()}")
    print(f"PT192: {parsed[0x22].hex()}")
    if args.verify_roundtrip:
        print("Round-trip:", "PASS" if parsed[0x22] == pt else "FAIL")


def main():
    ap = argparse.ArgumentParser(description="UART utility for aes_192_only FPGA top")
    ap.add_argument("--port", default="/dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--plaintext", default=DEFAULT_PT.hex())
    ap.add_argument("--key192", default=DEFAULT_K192.hex())
    ap.add_argument("--verify-roundtrip", action="store_true")
    run(ap.parse_args())


if __name__ == "__main__":
    main()
