`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.04.2026 19:20:39
// Design Name: 
// Module Name: INV_FINAL_ROUND
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


module INV_FINAL_ROUND(
    input [127:0] IN_DATA,   // R1
    input [127:0] K1,
    input [127:0] K0,
    output [127:0] OUT_DATA  // Plaintext
);

wire [127:0] x, y, z, r0;

// Step 1: XOR with K1
assign x = IN_DATA ^ K1;

// Step 2: InvMixColumns
INV_MIX_COLUMNS u1(
    .IN_DATA(x),
    .OUT_DATA(y)
);

// Step 3: InvShiftRows
INV_SHIFT_ROWS u2(
    .IN_DATA(y),
    .OUT_DATA(z)
);

// Step 4: InvSubBytes
INV_SUB_BYTES u3(
    .IN_DATA(z),
    .OUT_DATA(r0)
);

// Step 5: XOR with K0 → Plaintext
assign OUT_DATA = r0 ^ K0;

endmodule
