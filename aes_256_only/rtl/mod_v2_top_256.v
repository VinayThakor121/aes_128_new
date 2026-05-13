`timescale 1ns / 1ps

module mod_v2_top_256 (
    input              clk,
    input              rst,
    input  [255:0]     key,
    input  [127:0]     data_in,
    input              enc_dec,
    input              start,
    output [127:0]     data_out,
    output             done
);

wire [127:0] enc_out, dec_out;
wire enc_done, dec_done;
wire start_enc = start &  enc_dec;
wire start_dec = start & ~enc_dec;

mod_v2_encrypt_256 u_enc (
    .clk(clk), .rst(rst), .plaintext(data_in), .key(key),
    .start(start_enc), .ciphertext(enc_out), .done(enc_done)
);

mod_v2_decrypt_256 u_dec (
    .clk(clk), .rst(rst), .ciphertext(data_in), .key(key),
    .start(start_dec), .plaintext(dec_out), .done(dec_done)
);

assign data_out = enc_dec ? enc_out : dec_out;
assign done     = enc_dec ? enc_done : dec_done;

endmodule
