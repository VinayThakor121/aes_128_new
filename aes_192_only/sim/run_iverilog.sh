#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

iverilog -g2001 -o /tmp/aes192_modv2 \
  "$ROOT"/rtl/*.v "$ROOT"/uart/*.v "$ROOT"/tb/tb_mod_v2_aes192_only.v
vvp /tmp/aes192_modv2

iverilog -g2001 -o /tmp/aes192_uart \
  "$ROOT"/rtl/*.v "$ROOT"/uart/*.v "$ROOT"/tb/tb_uart_aes192_top.v
vvp /tmp/aes192_uart
