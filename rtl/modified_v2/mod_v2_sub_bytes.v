// Modified AES V2 – Forward SubBytes
// Paper: "Modified Advanced Encryption Standard Algorithm for Information Security"
//        (O.C. Abikoye et al.)
//
// Modification: SubBytes becomes round-key dependent.
//
// For round key rk[127:0] (column-major, same layout as AES state):
//   XORkey[i] = XOR of all 4 column-bytes in row i of the round key matrix
//     XORkey0 = rk[127:120] ^ rk[95:88]  ^ rk[63:56]  ^ rk[31:24]
//     XORkey1 = rk[119:112] ^ rk[87:80]  ^ rk[55:48]  ^ rk[23:16]
//     XORkey2 = rk[111:104] ^ rk[79:72]  ^ rk[47:40]  ^ rk[15:8]
//     XORkey3 = rk[103:96]  ^ rk[71:64]  ^ rk[39:32]  ^ rk[7:0]
//
// For every state byte b at (row i, col j):
//   out_byte = SBOX( b XOR XORkey[i] )
//
// Reuses existing aes_sbox_fwd primitive – no S-box duplication.
`timescale 1ns / 1ps

module mod_v2_sub_bytes (
    input  [127:0] data_in,
    input  [127:0] round_key,
    output [127:0] data_out
);

// ----------------------------------------------------------------
// XORkey generation: XOR all 4 row-bytes across columns
// Column-major layout: byte(row r, col c) = data[127 - (c*4+r)*8 -: 8]
//   byte indices per row: row 0 → 0,4,8,12 ; row 1 → 1,5,9,13 ; ...
//   bit positions:        row 0 → [127:120],[95:88],[63:56],[31:24]
//                         row 1 → [119:112],[87:80],[55:48],[23:16]
//                         row 2 → [111:104],[79:72],[47:40],[15:8]
//                         row 3 → [103:96] ,[71:64],[39:32],[7:0]
// ----------------------------------------------------------------
wire [7:0] xorkey0, xorkey1, xorkey2, xorkey3;

assign xorkey0 = round_key[127:120] ^ round_key[95:88]  ^ round_key[63:56]  ^ round_key[31:24];
assign xorkey1 = round_key[119:112] ^ round_key[87:80]  ^ round_key[55:48]  ^ round_key[23:16];
assign xorkey2 = round_key[111:104] ^ round_key[79:72]  ^ round_key[47:40]  ^ round_key[15:8];
assign xorkey3 = round_key[103:96]  ^ round_key[71:64]  ^ round_key[39:32]  ^ round_key[7:0];

// ----------------------------------------------------------------
// Apply SBOX( state_byte XOR XORkey[row] ) for each byte.
// Iterate over 4 columns; within each column instantiate 4 rows.
// byte(row r, col c) MSB position = 127 - c*32 - r*8
// ----------------------------------------------------------------
genvar g;
generate
    for (g = 0; g < 4; g = g + 1) begin : col_loop
        // Row 0
        aes_sbox_fwd u_r0 (
            .in_byte  (data_in[127 - g*32     -: 8] ^ xorkey0),
            .out_byte (data_out[127 - g*32     -: 8])
        );
        // Row 1
        aes_sbox_fwd u_r1 (
            .in_byte  (data_in[119 - g*32     -: 8] ^ xorkey1),
            .out_byte (data_out[119 - g*32     -: 8])
        );
        // Row 2
        aes_sbox_fwd u_r2 (
            .in_byte  (data_in[111 - g*32     -: 8] ^ xorkey2),
            .out_byte (data_out[111 - g*32     -: 8])
        );
        // Row 3
        aes_sbox_fwd u_r3 (
            .in_byte  (data_in[103 - g*32     -: 8] ^ xorkey3),
            .out_byte (data_out[103 - g*32     -: 8])
        );
    end
endgenerate

// Expose XORkeys for debug/testbench visibility
// (These wires are observable via hierarchical references in testbenches.)

endmodule
