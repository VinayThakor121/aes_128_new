## Basys 3 (XC7A35T) — Constraints for uart_aes256_top
## Vivado XDC format
##
## Board reference: Digilent Basys 3 Reference Manual, Rev. D
## On-board USB-UART bridge: FTDI FT2232HQ
##   FPGA pin A18 = UART_TXD  (FPGA → PC)
##   FPGA pin B18 = UART_RXD  (PC → FPGA)
## Reset button (active-high): BTNC at pin U18
## On-board 100 MHz clock: pin W5

## ---------------------------------------------------------------
## Clock (100 MHz)
## ---------------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} \
    [get_ports clk]

## ---------------------------------------------------------------
## UART
## ---------------------------------------------------------------
set_property PACKAGE_PIN A18 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]

set_property PACKAGE_PIN B18 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]

set_false_path -from [get_ports uart_rx_pin]

## ---------------------------------------------------------------
## Reset — centre button (active-high)
## ---------------------------------------------------------------
set_property PACKAGE_PIN U18 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

## ---------------------------------------------------------------
## Debug LEDs (LD0-LD7)
## ---------------------------------------------------------------
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]

## ---------------------------------------------------------------
## Timing constraints
## ---------------------------------------------------------------
## Clock period (10.000 ns / 100 MHz) is defined by create_clock above.
## No additional set_max_delay is needed for same-domain paths.
##
## Recommended Vivado implementation strategy for timing closure:
##   Synthesis  : Flow_AreaOptimized_high  (or Flow_PerfOptimized_high)
##   Opt design : -directive Explore
##   Place      : -directive AggressiveTiming
##   Post-place phys_opt: -directive AggressiveExplore
##   Route      : -directive AggressiveExplore
##   Post-route phys_opt: -directive AggressiveExplore

## ---------------------------------------------------------------
## Bitstream configuration
## ---------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
