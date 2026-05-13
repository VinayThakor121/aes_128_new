# aes_256_only

Standalone Modified AES V2 (AES-256 only) implementation with UART pipeline:
Laptop → UART → FPGA AES-256 encrypt/decrypt → UART → Laptop.

## Structure

- `rtl/`         — AES-256-only modified core and top-level flow
- `uart/`        — UART RX/TX/baud modules (shared, standalone copy)
- `tb/`          — AES-256 core and end-to-end UART testbenches
- `python/`      — PC-side UART sender/parser for AES-256-only protocol
- `sim/`         — Icarus simulation script
- `vivado/`      — Vivado project creation TCL
- `constraints/` — Basys 3 XDC for `uart_aes256_top`
- `scripts/`     — AES reference Python script

## AES-256 Modified V2 Summary

This implementation uses Modified AES V2 (Abikoye et al.):

- **Only change from standard AES**: `SubBytes` is replaced by `ModSubBytes`,
  which XORs each state byte with a round-key-derived value **before** the S-box.
- **Key parameters**: Nk=8, Nr=14, 15 round keys of 128 bits (1920 bits total).
- **Key expansion**: sequential 14-cycle design (`aes_key_expand_256_seq`) that
  keeps each cycle ≤ 8.5 ns — timing safe at 100 MHz on Artix-7.
  AES-256 specific extra SubWord (no RotWord, no Rcon) at every `i%8==4` position.
- **Round-trip**: encrypt(plaintext) → ciphertext → decrypt(ciphertext) → plaintext ✓

## Packet protocol (input, 54 bytes)

| Byte(s) | Value  | Description       |
|---------|--------|-------------------|
| 0       | `0xAA` | Start byte        |
| 1       | `0x03` | Command (AES-256) |
| 2–3     | `0x0030`| Payload length = 48 |
| 4–19    | —      | Plaintext (16 B)  |
| 20–51   | —      | Key-256  (32 B)   |
| 52      | —      | XOR checksum of bytes 4–51 |
| 53      | `0x55` | End byte          |

## Response protocol (output, 54 bytes)

Three frames of 18 bytes each:

| Frame | ID     | Content           |
|-------|--------|-------------------|
| 0     | `0x03` | Original plaintext (echoed back) |
| 1     | `0x13` | AES-256 ciphertext               |
| 2     | `0x23` | AES-256 decrypted plaintext      |

Each frame: `[ID (1B)][data (16B)][XOR checksum (1B)]`

## Running Simulation (Icarus Verilog)

```bash
cd aes_256_only/sim
bash run_iverilog.sh
```

Both tests must print `PASS`.

## Python UART Script (FPGA on Basys 3)

```bash
pip install pyserial
python aes_256_only/python/uart_aes256_send.py --port /dev/ttyUSB0 --baud 115200
```

## Vivado Project

```tcl
cd aes_256_only/vivado
vivado -mode batch -source create_project.tcl
```

Top module: `uart_aes256_top`
Target: Basys 3 / xc7a35tcpg236-1

## Known Modified V2 Test Vector

- Plaintext : `00112233445566778899aabbccddeeff`
- Key-256   : `000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f`
- Ciphertext (Modified V2): `0a6aff44e685399d3bbf12db93d70e09`  ← differs from standard AES
- Standard AES-256 CT      : `8ea2b7ca516745bfeafc49904b496089`
