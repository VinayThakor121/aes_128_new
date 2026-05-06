`timescale 1ns/1ps

module INV_LAST_ROUND(
    input clk,
    input [3:0] ROUND_KEY,
    input [127:0] IN_DATA,   // Cipher input
    input [127:0] IN_KEY,
    output [127:0] OUT_DATA  // Decrypted output
);

// =====================================================
// 🔑 KEY GENERATION (SAME AS ENCRYPTION)
// =====================================================
wire [127:0] keyout_0, keyout;

GENERATE_KEY t0(clk, ROUND_KEY, IN_KEY, keyout_0);
GENERATE_KEY t1(clk, ROUND_KEY, keyout_0, keyout);

// =====================================================
// 🔁 INTERNAL WIRES
// =====================================================
wire [127:0] sr;        // after XOR removal
wire [127:0] mod_out;   // after InvShiftRows
wire [127:0] sb;        // after INV_MOD_ADDITION

// =====================================================
// 🔥 STEP 1: Remove final XOR
// =====================================================
assign sr = IN_DATA ^ keyout;

// =====================================================
// 🔥 STEP 2: Inverse ShiftRows
// =====================================================
INV_SHIFT_ROWS u1(
    .IN_DATA(sr),
    .OUT_DATA(mod_out)
);

// =====================================================
// 🔥 STEP 3: Inverse MOD_ADDITION
// =====================================================
INV_MOD_ADDITION u2(
    .clk(clk),
    .IN_KEY(keyout_0),
    .IN_DATA(mod_out),
    .OUT_DATA(sb)
);

// =====================================================
// 🔥 STEP 4: Inverse SubBytes
// =====================================================
INV_SUB_BYTES u3(
    .IN_DATA(sb),
    .OUT_DATA(OUT_DATA)
);

endmodule