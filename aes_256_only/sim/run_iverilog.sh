#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

iverilog -g2001 -o /tmp/aes256_modv2 \
  "$ROOT"/rtl/*.v "$ROOT"/uart/*.v "$ROOT"/tb/tb_mod_v2_aes256_only.v
vvp /tmp/aes256_modv2

iverilog -g2001 -o /tmp/aes256_uart \
  "$ROOT"/rtl/*.v "$ROOT"/uart/*.v "$ROOT"/tb/tb_uart_aes256_top.v
vvp /tmp/aes256_uart
