`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.04.2026 19:34:39
// Design Name: 
// Module Name: INV_ROUND_ITERATION_updated
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module INV_ROUND_ITERATION_updated(
    input clk,
    input [3:0] ROUND_KEY,
    input [127:0] IN_DATA,
    input [127:0] IN_KEY,
    output [127:0] OUT_DATA
);

// Proper key expansion (same as encryption)
wire [127:0] keyout_0, keyout_1, OUT_KEY;

GENERATE_KEY t0(clk, ROUND_KEY, IN_KEY, keyout_0);
GENERATE_KEY t1(clk, ROUND_KEY, keyout_0, keyout_1);
GENERATE_KEY t2(clk, ROUND_KEY, keyout_1, OUT_KEY);

// Internal wires
wire [127:0] x1, x2, x3, x4, x5;

// Step 1: Remove final XOR
assign x1 = IN_DATA ^ OUT_KEY;

// Step 2: InvMixColumns
INV_MIX_COLUMNS u1(.IN_DATA(x1), .OUT_DATA(x2));

// Step 3: InvMOD_ADDITION
INV_MOD_ADDITION u2(
    .clk(clk),
    .IN_KEY(keyout_1),
    .IN_DATA(x2),
    .OUT_DATA(x3)
);

// Step 4: InvShiftRows
INV_SHIFT_ROWS u3(.IN_DATA(x3), .OUT_DATA(x4));

// Step 5: Remove XOR with keyout_0
assign x5 = x4 ^ keyout_0;

// Step 6: InvSubBytes
INV_SUB_BYTES u4(.IN_DATA(x5), .OUT_DATA(OUT_DATA));

endmodule