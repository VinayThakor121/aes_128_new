// UART Baud Rate Generator
// Produces a 1-cycle high pulse (baud_tick) every 1/(BAUD*OVERSAMPLE) seconds.
//
// Default parameters target 115200 baud with 16× oversampling at 100 MHz:
//   DIVISOR = 100_000_000 / (115_200 × 16) = 54
//   Actual baud ≈ 115_741 (error < 0.5 %, well within UART spec)
//
// The 10-bit counter covers all standard baud rates:
//   9600 baud   → DIVISOR = 651  (10 bits needed)
//   115200 baud → DIVISOR = 54   (6 bits needed)
//   250000 baud → DIVISOR = 25   (5 bits needed, used in simulation)
`timescale 1ns / 1ps

module uart_baud_gen #(
    parameter CLK_HZ     = 100_000_000,
    parameter BAUD       = 115_200,
    parameter OVERSAMPLE = 16
) (
    input  clk,
    input  rst,
    output baud_tick
);

// Integer division — truncation is intentional; the resulting baud-rate
// error is < 2 % for all standard rates at 100 MHz.
localparam DIVISOR = CLK_HZ / (BAUD * OVERSAMPLE);

reg [9:0] cnt;

assign baud_tick = (cnt == DIVISOR - 1);

always @(posedge clk or posedge rst) begin
    if (rst)
        cnt <= 10'd0;
    else if (baud_tick)
        cnt <= 10'd0;
    else
        cnt <= cnt + 10'd1;
end

endmodule
