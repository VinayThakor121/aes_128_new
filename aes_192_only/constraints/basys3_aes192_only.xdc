## Basys 3 (XC7A35T) — Constraints for uart_aes192_top
## Vivado XDC format
##
## Board reference: Digilent Basys 3 Reference Manual, Rev. D
## On-board USB-UART bridge: FTDI FT2232HQ
##   FPGA pin A18 = UART_TXD  (FPGA → PC, data out of FPGA)
##   FPGA pin B18 = UART_RXD  (PC → FPGA, data into FPGA)
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
## FPGA transmits to PC (TXD from FPGA's perspective)
set_property PACKAGE_PIN A18 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]

## FPGA receives from PC (RXD into FPGA)
set_property PACKAGE_PIN B18 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]

## UART RX is an asynchronous input — suppress false-path timing warnings
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
## The AES critical path (S-box chains) typically closes at ~150-200 MHz
## on Artix-7.  A 10 ns (100 MHz) constraint is easily achievable.
set_max_delay -datapath_only 10.000 \
    -from [get_clocks sys_clk_pin] \
    -to   [get_clocks sys_clk_pin]

## ---------------------------------------------------------------
## Bitstream configuration (optional but recommended for Basys 3)
## ---------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
