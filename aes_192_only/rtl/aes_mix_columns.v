// AES MixColumns: multiply each column by the AES MDS matrix in GF(2^8).
// FIPS-197 Section 5.1.3
//
// For each column [s0,s1,s2,s3]:
//   s'0 = 2*s0 ^ 3*s1 ^   s2 ^   s3
//   s'1 =   s0 ^ 2*s1 ^ 3*s2 ^   s3
//   s'2 =   s0 ^   s1 ^ 2*s2 ^ 3*s3
//   s'3 = 3*s0 ^   s1 ^   s2 ^ 2*s3
// where arithmetic is in GF(2^8) with polynomial x^8+x^4+x^3+x+1.
`timescale 1ns / 1ps

module aes_mix_columns (
    input  [127:0] data_in,
    output [127:0] data_out
);

// GF(2^8) multiply by 2 (xtime)
function [7:0] xtime;
    input [7:0] a;
    xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
endfunction

// GF(2^8) multiply by 3
function [7:0] gf3;
    input [7:0] a;
    gf3 = xtime(a) ^ a;
endfunction

// Mix a single 32-bit column
function [31:0] mix_col;
    input [31:0] col;
    reg [7:0] s0, s1, s2, s3;
    begin
        s0 = col[31:24];
        s1 = col[23:16];
        s2 = col[15: 8];
        s3 = col[ 7: 0];
        mix_col[31:24] = xtime(s0) ^ gf3(s1) ^      s2  ^      s3;
        mix_col[23:16] =      s0  ^ xtime(s1) ^ gf3(s2) ^      s3;
        mix_col[15: 8] =      s0  ^      s1  ^ xtime(s2) ^ gf3(s3);
        mix_col[ 7: 0] = gf3(s0)  ^      s1  ^      s2  ^ xtime(s3);
    end
endfunction

assign data_out[127:96] = mix_col(data_in[127:96]);
assign data_out[ 95:64] = mix_col(data_in[ 95:64]);
assign data_out[ 63:32] = mix_col(data_in[ 63:32]);
assign data_out[ 31: 0] = mix_col(data_in[ 31: 0]);

endmodule
