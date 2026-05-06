// FPGA Top-Level — UART ↔ Modified AES V2 (128/192/256)
//
// Target:  Basys 3 (Xilinx Artix-7 XC7A35T)
// Clock:   100 MHz on-board oscillator (W5)
// UART TX: pin A18  (FPGA → PC via on-board USB-UART bridge)
// UART RX: pin B18  (PC → FPGA via on-board USB-UART bridge)
// Reset:   active-high; tie to BTNC (U18) in the XDC
//
// Workflow:
//   1. PC sends one 94-byte packet (see packet_decoder for format).
//   2. FPGA decodes the packet, runs AES-128/192/256 encrypt then decrypt
//      using Modified AES V2.
//   3. FPGA sends back six 18-byte result frames in order:
//        0x11 AES-128 ciphertext
//        0x12 AES-192 ciphertext
//        0x13 AES-256 ciphertext
//        0x21 AES-128 decrypted plaintext
//        0x22 AES-192 decrypted plaintext
//        0x23 AES-256 decrypted plaintext
//
// Debug LEDs (led[7:0]):
//   led[0] — pkt_valid     (packet accepted)
//   led[1] — pkt_error     (framing/checksum error)
//   led[2] — results_ready (all AES work done)
//   led[3] — tx_done       (all results transmitted)
//   led[7:4] — aes_controller FSM state (visible in Vivado logic analyser)
`timescale 1ns / 1ps

module uart_aes_top #(
    parameter CLK_HZ = 100_000_000,
    parameter BAUD   = 115_200
) (
    input  clk,
    input  rst,
    input  uart_rx_pin,
    output uart_tx_pin,
    output [7:0] led       // optional debug — connect to LD0..LD7 in XDC
);

// ---------------------------------------------------------------
// Baud-rate generator (shared by RX and TX)
// ---------------------------------------------------------------
wire baud_tick;
uart_baud_gen #(
    .CLK_HZ(CLK_HZ),
    .BAUD  (BAUD)
) u_baud (
    .clk      (clk),
    .rst      (rst),
    .baud_tick(baud_tick)
);

// ---------------------------------------------------------------
// UART receiver
// ---------------------------------------------------------------
wire [7:0] rx_byte;
wire       rx_valid;
uart_rx u_rx (
    .clk      (clk),
    .rst      (rst),
    .baud_tick(baud_tick),
    .rx_serial(uart_rx_pin),
    .rx_byte  (rx_byte),
    .rx_valid (rx_valid)
);

// ---------------------------------------------------------------
// Packet decoder
// ---------------------------------------------------------------
wire [127:0] plaintext, key128;
wire [191:0] key192;
wire [255:0] key256;
wire         pkt_valid, pkt_error;
packet_decoder u_pkt (
    .clk      (clk),
    .rst      (rst),
    .rx_byte  (rx_byte),
    .rx_valid (rx_valid),
    .plaintext(plaintext),
    .key128   (key128),
    .key192   (key192),
    .key256   (key256),
    .pkt_valid(pkt_valid),
    .pkt_error(pkt_error)
);

// ---------------------------------------------------------------
// AES controller (3× mod_v2_top)
// ---------------------------------------------------------------
wire [127:0] ct128, ct192, ct256;
wire [127:0] pt128, pt192, pt256;
wire         results_ready;
wire [3:0]   dbg_fsm_state;   // unused outside debug

aes_controller u_ctrl (
    .clk          (clk),
    .rst          (rst),
    .plaintext    (plaintext),
    .key128       (key128),
    .key192       (key192),
    .key256       (key256),
    .pkt_valid    (pkt_valid),
    .ct128        (ct128),
    .ct192        (ct192),
    .ct256        (ct256),
    .pt128        (pt128),
    .pt192        (pt192),
    .pt256        (pt256),
    .results_ready(results_ready)
);

// ---------------------------------------------------------------
// UART transmitter
// ---------------------------------------------------------------
wire [7:0] tx_byte;
wire       tx_valid, tx_ready;
uart_tx u_tx (
    .clk      (clk),
    .rst      (rst),
    .baud_tick(baud_tick),
    .tx_byte  (tx_byte),
    .tx_valid (tx_valid),
    .tx_serial(uart_tx_pin),
    .tx_ready (tx_ready)
);

// ---------------------------------------------------------------
// Output formatter
// ---------------------------------------------------------------
wire tx_done;
output_formatter u_fmt (
    .clk          (clk),
    .rst          (rst),
    .ct128        (ct128),
    .ct192        (ct192),
    .ct256        (ct256),
    .pt128        (pt128),
    .pt192        (pt192),
    .pt256        (pt256),
    .results_ready(results_ready),
    .tx_byte      (tx_byte),
    .tx_valid     (tx_valid),
    .tx_ready     (tx_ready),
    .tx_done      (tx_done)
);

// ---------------------------------------------------------------
// Debug LED assignments (sticky: hold until next event)
// ---------------------------------------------------------------
reg [7:0] led_r;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        led_r <= 8'd0;
    end else begin
        if (pkt_valid)     led_r[0] <= 1'b1;
        if (pkt_error)     led_r[1] <= 1'b1;
        if (results_ready) led_r[2] <= 1'b1;
        if (tx_done)       led_r[3] <= 1'b1;
        // Clear on next packet accepted
        if (pkt_valid)     led_r[3:1] <= 3'b0;
    end
end
assign led = led_r;

endmodule
