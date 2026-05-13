`timescale 1ns / 1ps
//
// uart_aes256_top — FPGA top-level for AES-256-only standalone
//
// Target:  Basys 3 (Xilinx Artix-7 XC7A35T)
// Clock:   100 MHz on-board oscillator (W5)
// UART TX: pin A18  (FPGA → PC via on-board USB-UART bridge)
// UART RX: pin B18  (PC → FPGA via on-board USB-UART bridge)
// Reset:   active-high; tie to BTNC (U18) in the XDC
//
// Flow:
//   1. PC sends one 54-byte packet (AES-256 key + plaintext).
//   2. FPGA decodes the packet, runs AES-256 encrypt then decrypt
//      using Modified AES V2.
//   3. FPGA sends back three 18-byte result frames:
//        0x03 original plaintext
//        0x13 AES-256 ciphertext
//        0x23 AES-256 decrypted plaintext
//
// Debug LEDs:
//   led[0] — pkt_valid     (packet accepted)
//   led[1] — pkt_error     (framing/checksum error)
//   led[2] — results_ready (all AES work done)
//   led[3] — tx_done       (all results transmitted)

module uart_aes256_top #(
    parameter CLK_HZ = 100_000_000,
    parameter BAUD   = 115_200
) (
    input  clk,
    input  rst,
    input  uart_rx_pin,
    output uart_tx_pin,
    output [7:0] led
);

wire baud_tick;
uart_baud_gen #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_baud (
    .clk(clk), .rst(rst), .baud_tick(baud_tick)
);

wire [7:0] rx_byte;
wire rx_valid;
uart_rx u_rx (
    .clk(clk), .rst(rst), .baud_tick(baud_tick),
    .rx_serial(uart_rx_pin), .rx_byte(rx_byte), .rx_valid(rx_valid)
);

wire [127:0] plaintext;
wire [255:0] key256;
wire pkt_valid, pkt_error;
packet_decoder_256 u_pkt (
    .clk(clk), .rst(rst), .rx_byte(rx_byte), .rx_valid(rx_valid),
    .plaintext(plaintext), .key256(key256),
    .pkt_valid(pkt_valid), .pkt_error(pkt_error)
);

wire [127:0] ct256, pt256, orig_pt;
wire results_ready;
aes_controller_256 u_ctrl (
    .clk(clk), .rst(rst), .plaintext(plaintext), .key256(key256),
    .pkt_valid(pkt_valid),
    .orig_pt(orig_pt), .ct256(ct256), .pt256(pt256),
    .results_ready(results_ready)
);

wire [7:0] tx_byte;
wire tx_valid, tx_ready;
uart_tx u_tx (
    .clk(clk), .rst(rst), .baud_tick(baud_tick),
    .tx_byte(tx_byte), .tx_valid(tx_valid),
    .tx_serial(uart_tx_pin), .tx_ready(tx_ready)
);

wire tx_done;
output_formatter_256 u_fmt (
    .clk(clk), .rst(rst),
    .orig_pt(orig_pt), .ct256(ct256), .pt256(pt256),
    .results_ready(results_ready),
    .tx_byte(tx_byte), .tx_valid(tx_valid), .tx_ready(tx_ready),
    .tx_done(tx_done)
);

reg [7:0] led_r;
always @(posedge clk or posedge rst) begin
    if (rst) led_r <= 8'd0;
    else begin
        if (pkt_valid)     led_r[0] <= 1'b1;
        if (pkt_error)     led_r[1] <= 1'b1;
        if (results_ready) led_r[2] <= 1'b1;
        if (tx_done)       led_r[3] <= 1'b1;
        if (pkt_valid)     led_r[3:1] <= 3'b0;
    end
end
assign led = led_r;

endmodule
