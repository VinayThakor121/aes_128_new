// Modified AES V2 – Parameterized Top Module (Encryption + Decryption)
// Paper: "Modified Advanced Encryption Standard Algorithm for Information Security"
//        (O.C. Abikoye et al.)
//
// Supports KEY_SIZE = 128, 192, or 256.
// enc_dec = 1 → encryption mode
// enc_dec = 0 → decryption mode
//
// Instantiates mod_v2_encrypt and mod_v2_decrypt, each with their own
// key expansion; start pulse is steered to the selected core.
`timescale 1ns / 1ps

module mod_v2_top #(
    parameter KEY_SIZE = 128   // 128, 192, or 256
) (
    input                 clk,
    input                 rst,
    input  [KEY_SIZE-1:0] key,
    input  [127:0]        data_in,   // plaintext for encrypt, ciphertext for decrypt
    input                 enc_dec,   // 1 = encrypt, 0 = decrypt
    input                 start,
    output [127:0]        data_out,  // ciphertext for encrypt, plaintext for decrypt
    output                done
);

wire [127:0] enc_out, dec_out;
wire         enc_done, dec_done;

wire start_enc = start &  enc_dec;
wire start_dec = start & ~enc_dec;

mod_v2_encrypt #(.KEY_SIZE(KEY_SIZE)) u_enc (
    .clk        (clk),
    .rst        (rst),
    .plaintext  (data_in),
    .key        (key),
    .start      (start_enc),
    .ciphertext (enc_out),
    .done       (enc_done)
);

mod_v2_decrypt #(.KEY_SIZE(KEY_SIZE)) u_dec (
    .clk        (clk),
    .rst        (rst),
    .ciphertext (data_in),
    .key        (key),
    .start      (start_dec),
    .plaintext  (dec_out),
    .done       (dec_done)
);

assign data_out = enc_dec ? enc_out  : dec_out;
assign done     = enc_dec ? enc_done : dec_done;

endmodule
