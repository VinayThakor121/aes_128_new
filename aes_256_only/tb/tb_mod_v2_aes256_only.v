`timescale 1ns / 1ps
//
// tb_mod_v2_aes256_only — Core encrypt/decrypt testbench for AES-256 Modified V2
//
// Test vector: NIST FIPS-197 Appendix C.3 key and plaintext.
// Expected Modified V2 ciphertext differs from standard AES-256 (modification active).
// Primary test: round-trip correctness — encrypt → decrypt → original plaintext.

module tb_mod_v2_aes256_only;

localparam [255:0] KEY       = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
localparam [127:0] PLAINTEXT = 128'h00112233445566778899aabbccddeeff;

// Standard AES-256 NIST ciphertext (used only to verify modification is active)
localparam [127:0] STD_AES_CT  = 128'h8ea2b7ca516745bfeafc49904b496089;
// Known Modified AES V2 ciphertext (from simulation; differs from standard AES)
localparam [127:0] MOD_CT_REF  = 128'h0a6aff44e685399d3bbf12db93d70e09;

reg clk = 0, rst = 1, start = 0;
wire [127:0] ciphertext, recovered_pt;
wire enc_done, dec_done;
reg [127:0] ct_latch = 0;
reg dec_start = 0;

always #5 clk = ~clk;

mod_v2_encrypt_256 u_enc (
    .clk(clk), .rst(rst), .plaintext(PLAINTEXT), .key(KEY),
    .start(start), .ciphertext(ciphertext), .done(enc_done)
);
mod_v2_decrypt_256 u_dec (
    .clk(clk), .rst(rst), .ciphertext(ct_latch), .key(KEY),
    .start(dec_start), .plaintext(recovered_pt), .done(dec_done)
);

integer pass_count = 0;
integer fail_count = 0;

initial begin
    repeat (3) @(posedge clk); rst = 0;
    @(posedge clk); start = 1; @(posedge clk); start = 0;
    @(posedge enc_done); @(posedge clk);

    // Verify ciphertext differs from standard AES (modification is active)
    if (ciphertext !== STD_AES_CT) pass_count = pass_count + 1;
    else begin fail_count = fail_count + 1; $display("WARN: ciphertext matches standard AES — modification may be inactive"); end

    // Verify ciphertext matches known Modified V2 reference
    if (ciphertext === MOD_CT_REF) pass_count = pass_count + 1;
    else begin fail_count = fail_count + 1; $display("WARN: ciphertext does not match MOD_CT_REF %h (got %h)", MOD_CT_REF, ciphertext); end

    ct_latch = ciphertext;
    @(posedge clk); dec_start = 1; @(posedge clk); dec_start = 0;
    @(posedge dec_done); @(posedge clk);

    if (recovered_pt === PLAINTEXT) pass_count = pass_count + 1;
    else fail_count = fail_count + 1;

    $display("");
    $display("## AES-256 CORE TEST (Modified V2)");
    $display("");
    $display("Input Plaintext:");
    $display("%H", PLAINTEXT);
    $display("");
    $display("Encryption Key:");
    $display("%H", KEY);
    $display("");
    $display("Encrypted Ciphertext:");
    $display("%H", ciphertext);
    $display("");
    $display("Decrypted Plaintext:");
    $display("%H", recovered_pt);
    $display("");
    if (recovered_pt === PLAINTEXT) begin
        $display("RESULT:");
        $display("PASS - Retrieved plaintext matches original plaintext");
    end else begin
        $display("RESULT:");
        $display("FAIL - Retrieved plaintext does NOT match original plaintext");
    end
    $display("");
    $display("AES256_ONLY_MOD_V2 PASS=%0d FAIL=%0d CT=%h PT=%h",
             pass_count, fail_count, ciphertext, recovered_pt);
    $finish;
end

initial begin #500000; $display("TIMEOUT"); $finish; end

endmodule
