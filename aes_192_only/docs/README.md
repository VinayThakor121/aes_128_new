# aes_192_only

Standalone Modified AES V2 (AES-192 only) implementation with UART pipeline:
Laptop -> UART -> FPGA AES-192 encrypt/decrypt -> UART -> Laptop.

## Structure
- `rtl/`: AES-192-only modified core and top-level flow
- `uart/`: UART RX/TX/baud modules
- `tb/`: AES-192 core and end-to-end UART testbenches
- `python/`: PC-side UART sender/parser for AES-192-only protocol
- `sim/`: Icarus simulation script
- `vivado/`: Vivado project creation TCL
- `constraints/`: Basys 3 XDC for `uart_aes192_top`

## Packet protocol (input, 46 bytes)
- `0xAA 0x02 0x00 0x28`
- Plaintext (16B)
- Key192 (24B)
- XOR checksum (payload only)
- `0x55`

## Response protocol (output, 36 bytes)
Two frames of 18 bytes each:
- `0x12` + CT192 (16B) + XOR checksum
- `0x22` + PT192 (16B) + XOR checksum
