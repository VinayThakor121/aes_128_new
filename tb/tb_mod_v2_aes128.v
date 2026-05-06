// Modified AES V2 – AES-128 Testbench
// Paper: "Modified Advanced Encryption Standard Algorithm for Information Security"
//        (O.C. Abikoye et al.)
//
// Test vectors: NIST FIPS-197 Appendix C.1 key and plaintext.
// No expected ciphertext is hardcoded (Modified V2 produces a different
// ciphertext than standard AES). The primary test is round-trip correctness:
//   encrypt(plaintext, key) → ciphertext
//   decrypt(ciphertext, key) → recovered_plaintext == plaintext
//
// Additional checks:
//   - The Modified V2 ciphertext must differ from the standard AES ciphertext,
//     confirming the modification is active.
//   - XORkey values for round 1 are printed for waveform verification.
`timescale 1ns / 1ps

module tb_mod_v2_aes128;

localparam KEY_SIZE = 128;

// NIST FIPS-197 Appendix C.1
localparam [127:0] KEY           = 128'h000102030405060708090a0b0c0d0e0f;
localparam [127:0] PLAINTEXT     = 128'h00112233445566778899aabbccddeeff;
// Standard AES-128 expected ciphertext (to verify the modification is active)
localparam [127:0] STD_AES_CT    = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

reg clk = 1'b0;
reg rst = 1'b1;
reg start = 1'b0;

wire [127:0] ciphertext;
wire         enc_done;
wire [127:0] recovered_pt;
wire         dec_done;

// --------------------------------------------------------
// Clock: 10 ns period
// --------------------------------------------------------
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
// DUT: Modified V2 Decrypt (fed with the encrypted ciphertext)
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
    $display("  Modified AES V2 – 128-bit Key Test");
    $display("====================================================");
    $display("  Key       : %h", KEY);
    $display("  Plaintext : %h", PLAINTEXT);

    @(posedge clk); @(posedge clk); @(posedge clk);
    rst = 1'b0;

    // Start encryption
    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    // Wait for encryption done
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

    // Print XORkey debug values for round 1 (from encrypt datapath)
    $display("\n--- Round-1 XORkeys (from encrypt u_sb, round_cnt=1) ---");
    $display("  XORkey0: %h", u_enc.u_sb.xorkey0);
    $display("  XORkey1: %h", u_enc.u_sb.xorkey1);
    $display("  XORkey2: %h", u_enc.u_sb.xorkey2);
    $display("  XORkey3: %h", u_enc.u_sb.xorkey3);

    // Start decryption with the produced ciphertext
    ct_latch = ciphertext;
    @(posedge clk);
    dec_start = 1'b1;
    @(posedge clk);
    dec_start = 1'b0;

    // Wait for decryption done
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

// Safety timeout
initial begin
    #200000;
    $display("TIMEOUT");
    $finish;
end

endmodule
