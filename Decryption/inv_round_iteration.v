`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.03.2026 14:55:34
// Design Name: 
// Module Name: INV_ROUND_ITERATION
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

`timescale 1ns / 1ps

module INV_ROUND_ITERATION(
    input clk,
    input [3:0] ROUND_KEY,
    input [127:0] IN_DATA,   // Cipher input
    input [127:0] IN_KEY,
    output [127:0] OUT_DATA
);

// =====================================================
// 🔑 KEY GENERATION (SAME AS ENCRYPTION)
// =====================================================
wire [127:0] keyout_0, keyout_1, OUT_KEY;

GENERATE_KEY t0(clk, ROUND_KEY, IN_KEY, keyout_0);
GENERATE_KEY t1(clk, ROUND_KEY, keyout_0, keyout_1);
GENERATE_KEY t2(clk, ROUND_KEY, keyout_1, OUT_KEY);

// =====================================================
// 🔁 INTERNAL WIRES
// =====================================================
wire [127:0] mcl;
wire [127:0] mod_add;
wire [127:0] sr;
wire [127:0] xor_op;
wire [127:0] sb;

// =====================================================
// 🔥 STEP 1: Remove final XOR
// =====================================================
assign mcl = IN_DATA ^ OUT_KEY;

// =====================================================
// 🔥 STEP 2: Inverse MixColumns
// =====================================================
INV_MIX_COLUMNS u1(
    .IN_DATA(mcl),
    .OUT_DATA(mod_add)
);

// =====================================================
// 🔥 STEP 3: Inverse MOD_ADDITION
// =====================================================
INV_MOD_ADDITION u2(
    .clk(clk),
    .IN_KEY(keyout_1),
    .IN_DATA(mod_add),
    .OUT_DATA(sr)
);

// =====================================================
// 🔥 STEP 4: Inverse ShiftRows
// =====================================================
INV_SHIFT_ROWS u3(
    .IN_DATA(sr),
    .OUT_DATA(xor_op)
);

// =====================================================
// 🔥 STEP 5: Remove XOR with keyout_0
// =====================================================
assign sb = xor_op ^ keyout_0;

// =====================================================
// 🔥 STEP 6: Inverse SubBytes
// =====================================================
INV_SUB_BYTES u4(
    .IN_DATA(sb),
    .OUT_DATA(OUT_DATA)
);

endmodule
