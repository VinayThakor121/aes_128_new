`timescale 1ns / 1ps

module tb_mod_v2_aes192_only;
localparam [191:0] KEY       = 192'h000102030405060708090a0b0c0d0e0f1011121314151617;
localparam [127:0] PLAINTEXT = 128'h00112233445566778899aabbccddeeff;
localparam [127:0] STD_AES_CT = 128'hdda97ca4864cdfe06eaf70a0ec0d7191;
localparam [127:0] MOD_CT_REF = 128'h1c556f67dda70687553f924d7c153246;

reg clk = 0, rst = 1, start = 0;
wire [127:0] ciphertext, recovered_pt;
wire enc_done, dec_done;
reg [127:0] ct_latch = 0;
reg dec_start = 0;

always #5 clk = ~clk;

mod_v2_encrypt_192 u_enc (.clk(clk), .rst(rst), .plaintext(PLAINTEXT), .key(KEY), .start(start), .ciphertext(ciphertext), .done(enc_done));
mod_v2_decrypt_192 u_dec (.clk(clk), .rst(rst), .ciphertext(ct_latch), .key(KEY), .start(dec_start), .plaintext(recovered_pt), .done(dec_done));

integer pass_count = 0;
integer fail_count = 0;

initial begin
    repeat (3) @(posedge clk); rst = 0;
    @(posedge clk); start = 1; @(posedge clk); start = 0;
    @(posedge enc_done); @(posedge clk);

    if (ciphertext !== STD_AES_CT) pass_count = pass_count + 1; else fail_count = fail_count + 1;
    if (ciphertext === MOD_CT_REF) pass_count = pass_count + 1; else fail_count = fail_count + 1;

    ct_latch = ciphertext;
    @(posedge clk); dec_start = 1; @(posedge clk); dec_start = 0;
    @(posedge dec_done); @(posedge clk);

    if (recovered_pt === PLAINTEXT) pass_count = pass_count + 1; else fail_count = fail_count + 1;

    $display("AES192_ONLY_MOD_V2 PASS=%0d FAIL=%0d CT=%h PT=%h", pass_count, fail_count, ciphertext, recovered_pt);
    $finish;
end

initial begin #200000; $display("TIMEOUT"); $finish; end

endmodule
