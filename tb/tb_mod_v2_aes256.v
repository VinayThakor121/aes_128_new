// Modified AES V2 – AES-256 Testbench
// Paper: "Modified Advanced Encryption Standard Algorithm for Information Security"
//        (O.C. Abikoye et al.)
//
// Test vectors: NIST FIPS-197 Appendix C.3 key and plaintext.
// Primary test: round-trip correctness (encrypt → decrypt → original plaintext).
// Also verifies ciphertext differs from standard AES-256 (modification is active).
`timescale 1ns / 1ps

module tb_mod_v2_aes256;

localparam KEY_SIZE = 256;

// NIST FIPS-197 Appendix C.3
localparam [255:0] KEY        = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
localparam [127:0] PLAINTEXT  = 128'h00112233445566778899aabbccddeeff;
// Standard AES-256 expected ciphertext (to verify the modification is active)
localparam [127:0] STD_AES_CT = 128'h8ea2b7ca516745bfeafc49904b496089;

reg clk = 1'b0;
reg rst = 1'b1;
reg start = 1'b0;

wire [127:0] ciphertext;
wire         enc_done;
wire [127:0] recovered_pt;
wire         dec_done;

always #5 clk = ~clk;

// --------------------------------------------------------
// DUT: Modified V2 Encrypt
// --------------------------------------------------------
mod_v2_encrypt #(.KEY_SIZE(KEY_SIZE)) u_enc (
    .clk        (clk),
    .rst        (rst),
    .plaintext  (PLAINTEXT),
    .key        (KEY),
    .start      (start),
    .ciphertext (ciphertext),
    .done       (enc_done)
);

// --------------------------------------------------------
// DUT: Modified V2 Decrypt
// --------------------------------------------------------
reg  [127:0] ct_latch  = 128'd0;
reg          dec_start = 1'b0;

mod_v2_decrypt #(.KEY_SIZE(KEY_SIZE)) u_dec (
    .clk        (clk),
    .rst        (rst),
    .ciphertext (ct_latch),
    .key        (KEY),
    .start      (dec_start),
    .plaintext  (recovered_pt),
    .done       (dec_done)
);

// --------------------------------------------------------
// Stimulus
// --------------------------------------------------------
integer pass_count = 0;
integer fail_count = 0;

initial begin
    $display("====================================================");
    $display("  Modified AES V2 – 256-bit Key Test");
    $display("====================================================");
    $display("  Key       : %h", KEY);
    $display("  Plaintext : %h", PLAINTEXT);

    @(posedge clk); @(posedge clk); @(posedge clk);
    rst = 1'b0;

    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    @(posedge enc_done);
    @(posedge clk);

    $display("\n--- Encryption ---");
    $display("  Ciphertext (Modified V2) : %h", ciphertext);
    $display("  Ciphertext (Standard AES): %h", STD_AES_CT);
    if (ciphertext !== STD_AES_CT) begin
        $display("  Modification active      : YES (ciphertexts differ as expected)");
        pass_count = pass_count + 1;
    end else begin
        $display("  WARNING: ciphertext equals standard AES – modification may be inactive!");
        fail_count = fail_count + 1;
    end

    $display("\n--- Round-1 XORkeys (from encrypt u_sb, round_cnt=1) ---");
    $display("  XORkey0: %h", u_enc.u_sb.xorkey0);
    $display("  XORkey1: %h", u_enc.u_sb.xorkey1);
    $display("  XORkey2: %h", u_enc.u_sb.xorkey2);
    $display("  XORkey3: %h", u_enc.u_sb.xorkey3);

    ct_latch = ciphertext;
    @(posedge clk);
    dec_start = 1'b1;
    @(posedge clk);
    dec_start = 1'b0;

    @(posedge dec_done);
    @(posedge clk);

    $display("\n--- Decryption (round-trip) ---");
    $display("  Recovered plaintext: %h", recovered_pt);
    $display("  Expected plaintext : %h", PLAINTEXT);
    if (recovered_pt === PLAINTEXT) begin
        $display("  RESULT             : PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  RESULT             : FAIL");
        fail_count = fail_count + 1;
    end

    $display("\n====================================================");
    $display("  PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("====================================================\n");
    $finish;
end

initial begin
    #200000;
    $display("TIMEOUT");
    $finish;
end

endmodule
