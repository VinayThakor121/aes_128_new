// Modified AES V2 – Inverse SubBytes
// Paper: "Modified Advanced Encryption Standard Algorithm for Information Security"
//        (O.C. Abikoye et al.)
//
// The inverse of ModSubBytes:
//   Forward:  out = SBOX( in XOR XORkey[row] )
//   Inverse:  out = InvSBOX( in ) XOR XORkey[row]
//
// XORkey generation is identical to the forward module:
//   XORkey[i] = XOR of all 4 column-bytes in row i of the supplied round key.
//
// Reuses existing aes_sbox_inv primitive – no S-box duplication.
`timescale 1ns / 1ps

module mod_v2_inv_sub_bytes (
    input  [127:0] data_in,
    input  [127:0] round_key,
    output [127:0] data_out
);

// ----------------------------------------------------------------
// XORkey generation (same layout as mod_v2_sub_bytes)
// ----------------------------------------------------------------
wire [7:0] xorkey0, xorkey1, xorkey2, xorkey3;

assign xorkey0 = round_key[127:120] ^ round_key[95:88]  ^ round_key[63:56]  ^ round_key[31:24];
assign xorkey1 = round_key[119:112] ^ round_key[87:80]  ^ round_key[55:48]  ^ round_key[23:16];
assign xorkey2 = round_key[111:104] ^ round_key[79:72]  ^ round_key[47:40]  ^ round_key[15:8];
assign xorkey3 = round_key[103:96]  ^ round_key[71:64]  ^ round_key[39:32]  ^ round_key[7:0];

// ----------------------------------------------------------------
// Apply InvSBOX then XOR with XORkey[row] for each byte.
// byte(row r, col c) MSB position = 127 - c*32 - r*8
// ----------------------------------------------------------------
genvar g;
generate
    for (g = 0; g < 4; g = g + 1) begin : col_loop
        wire [7:0] isb_r0, isb_r1, isb_r2, isb_r3;

        // Row 0
        aes_sbox_inv u_isb_r0 (
            .in_byte  (data_in[127 - g*32 -: 8]),
            .out_byte (isb_r0)
        );
        assign data_out[127 - g*32 -: 8] = isb_r0 ^ xorkey0;

        // Row 1
        aes_sbox_inv u_isb_r1 (
            .in_byte  (data_in[119 - g*32 -: 8]),
            .out_byte (isb_r1)
        );
        assign data_out[119 - g*32 -: 8] = isb_r1 ^ xorkey1;

        // Row 2
        aes_sbox_inv u_isb_r2 (
            .in_byte  (data_in[111 - g*32 -: 8]),
            .out_byte (isb_r2)
        );
        assign data_out[111 - g*32 -: 8] = isb_r2 ^ xorkey2;

        // Row 3
        aes_sbox_inv u_isb_r3 (
            .in_byte  (data_in[103 - g*32 -: 8]),
            .out_byte (isb_r3)
        );
        assign data_out[103 - g*32 -: 8] = isb_r3 ^ xorkey3;
    end
endgenerate

endmodule
