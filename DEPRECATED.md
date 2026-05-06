# DEPRECATED LEGACY FILES

The files in `Decryption/` and `Encrytption/` (note: typo in original directory name) are the **original** AES-128-only implementation. They are kept for reference but are **not used** in the new architecture.

## Issues in Legacy Files

| File | Issue |
|------|-------|
| `Encrytption/AES128_ENCRYPT_ITERATIVE.v` | Uses `add_bytes_mod` (modular byte addition) instead of XOR for AddRoundKey — **not FIPS-197 compliant** |
| `Encrytption/forward_substitution_box_local.v` | Contains only a Windows absolute path `include` (`C:/Testing/...`) — **broken, never synthesizable** |
| `Decryption/inv_add.v` | Uses `INV_MOD_ADDITION` (modular subtraction) instead of XOR — **not FIPS-197 compliant** |
| `Decryption/INV_ROUND_ITERATION_updated.v` | Duplicate of `inv_round_iteration.v` with same logic |
| `Decryption/tb_aes.v`, `testbench.v`, `tb_top.v`, `tb_uart.v` | Redundant testbenches with no NIST vectors |
| `Decryption/AES128_DECRYPT_STAGE4.v` | Mixed responsibilities; depends on non-compliant modules |

## Replaced By

See `rtl/` for the clean parameterized implementation and `tb/` for NIST FIPS-197 testbenches.
