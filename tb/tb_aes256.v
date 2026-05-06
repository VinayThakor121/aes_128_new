// AES-256 Testbench – NIST FIPS-197 Appendix C.3
// Key    : 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
// Plaintext : 00112233445566778899aabbccddeeff
// Ciphertext: 8ea2b7ca516745bfeafc49904b496089
`timescale 1ns / 1ps

module tb_aes256;

// NIST FIPS-197 Appendix C.3 test vector
localparam [255:0] KEY       = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
localparam [127:0] PLAINTEXT = 128'h00112233445566778899aabbccddeeff;
localparam [127:0] EXPECTED_CT = 128'h8ea2b7ca516745bfeafc49904b496089;

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
// DUT: Encrypt
// --------------------------------------------------------
aes_encrypt #(.KEY_SIZE(256)) u_enc (
    .clk        (clk),
    .rst        (rst),
    .plaintext  (PLAINTEXT),
    .key        (KEY),
    .start      (start),
    .ciphertext (ciphertext),
    .done       (enc_done)
);

// --------------------------------------------------------
// DUT: Decrypt
// --------------------------------------------------------
reg  [127:0] ct_latch  = 128'd0;
reg          dec_start = 1'b0;

aes_decrypt #(.KEY_SIZE(256)) u_dec (
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
    $display("  AES-256 Test – NIST FIPS-197 Appendix C.3");
    $display("====================================================");
    $display("  Key       : %h", KEY);
    $display("  Plaintext : %h", PLAINTEXT);
    $display("  Expected  : %h", EXPECTED_CT);

    @(posedge clk); @(posedge clk); @(posedge clk);
    rst = 1'b0;

    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    @(posedge enc_done);
    @(posedge clk);

    $display("\n--- Encryption ---");
    $display("  Got       : %h", ciphertext);
    if (ciphertext === EXPECTED_CT) begin
        $display("  RESULT    : PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  RESULT    : FAIL");
        fail_count = fail_count + 1;
    end

    ct_latch = ciphertext;
    @(posedge clk);
    dec_start = 1'b1;
    @(posedge clk);
    dec_start = 1'b0;

    @(posedge dec_done);
    @(posedge clk);

    $display("\n--- Decryption ---");
    $display("  Got       : %h", recovered_pt);
    if (recovered_pt === PLAINTEXT) begin
        $display("  RESULT    : PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  RESULT    : FAIL  (expected %h)", PLAINTEXT);
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
