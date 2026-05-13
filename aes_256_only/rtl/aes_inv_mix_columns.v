// AES InvMixColumns: multiply each column by the AES inverse MDS matrix in GF(2^8).
// FIPS-197 Section 5.3.3
//
// For each column [s0,s1,s2,s3]:
//   s'0 = 0x0e*s0 ^ 0x0b*s1 ^ 0x0d*s2 ^ 0x09*s3
//   s'1 = 0x09*s0 ^ 0x0e*s1 ^ 0x0b*s2 ^ 0x0d*s3
//   s'2 = 0x0d*s0 ^ 0x09*s1 ^ 0x0e*s2 ^ 0x0b*s3
//   s'3 = 0x0b*s0 ^ 0x0d*s1 ^ 0x09*s2 ^ 0x0e*s3
`timescale 1ns / 1ps

module aes_inv_mix_columns (
    input  [127:0] data_in,
    output [127:0] data_out
);

// GF(2^8) multiply by 2
function [7:0] xtime;
    input [7:0] a;
    xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
endfunction

// GF(2^8) multiply by any small constant (up to 4 bits)
function [7:0] gf_mul;
    input [7:0] a;
    input [3:0] b;
    reg [7:0] a2, a4, a8;
    begin
        a2 = xtime(a);
        a4 = xtime(a2);
        a8 = xtime(a4);
        gf_mul = (b[0] ? a  : 8'h00)
               ^ (b[1] ? a2 : 8'h00)
               ^ (b[2] ? a4 : 8'h00)
               ^ (b[3] ? a8 : 8'h00);
    end
endfunction

// Inverse mix of a single 32-bit column
function [31:0] inv_mix_col;
    input [31:0] col;
    reg [7:0] s0, s1, s2, s3;
    begin
        s0 = col[31:24];
        s1 = col[23:16];
        s2 = col[15: 8];
        s3 = col[ 7: 0];
        inv_mix_col[31:24] = gf_mul(s0,4'he) ^ gf_mul(s1,4'hb) ^ gf_mul(s2,4'hd) ^ gf_mul(s3,4'h9);
        inv_mix_col[23:16] = gf_mul(s0,4'h9) ^ gf_mul(s1,4'he) ^ gf_mul(s2,4'hb) ^ gf_mul(s3,4'hd);
        inv_mix_col[15: 8] = gf_mul(s0,4'hd) ^ gf_mul(s1,4'h9) ^ gf_mul(s2,4'he) ^ gf_mul(s3,4'hb);
        inv_mix_col[ 7: 0] = gf_mul(s0,4'hb) ^ gf_mul(s1,4'hd) ^ gf_mul(s2,4'h9) ^ gf_mul(s3,4'he);
    end
endfunction

assign data_out[127:96] = inv_mix_col(data_in[127:96]);
assign data_out[ 95:64] = inv_mix_col(data_in[ 95:64]);
assign data_out[ 63:32] = inv_mix_col(data_in[ 63:32]);
assign data_out[ 31: 0] = inv_mix_col(data_in[ 31: 0]);

endmodule
