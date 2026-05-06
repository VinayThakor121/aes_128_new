// tb_aes_controller.v — Unit testbench for aes_controller
//
// Pulses pkt_valid with NIST FIPS-197 Appendix C test vectors, waits for
// results_ready, then verifies:
//   1. All three decrypted plaintexts match the original plaintext
//      (round-trip correctness for Modified AES V2).
//   2. All three ciphertexts differ from the standard AES reference values
//      (confirming the V2 modification is active).
`timescale 1ns / 1ps

module tb_aes_controller;

reg clk = 0;
reg rst = 1;

// NIST FIPS-197 test vectors
localparam [127:0] PT   = 128'h00112233445566778899aabbccddeeff;
localparam [127:0] K128 = 128'h000102030405060708090a0b0c0d0e0f;
localparam [191:0] K192 = 192'h000102030405060708090a0b0c0d0e0f1011121314151617;
localparam [255:0] K256 = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;

// Standard AES reference ciphertexts (Modified V2 must differ from these)
localparam [127:0] STD_CT128 = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
localparam [127:0] STD_CT192 = 128'hdda97ca4864cdfe06eaf70a0ec0d7191;
localparam [127:0] STD_CT256 = 128'h8ea2b7ca516745bfeafc49904b496089;

reg pkt_valid_r = 1'b0;

wire [127:0] ct128, ct192, ct256;
wire [127:0] pt128, pt192, pt256;
wire         results_ready;

aes_controller u_ctrl (
    .clk          (clk),
    .rst          (rst),
    .plaintext    (PT),
    .key128       (K128),
    .key192       (K192),
    .key256       (K256),
    .pkt_valid    (pkt_valid_r),
    .ct128        (ct128),
    .ct192        (ct192),
    .ct256        (ct256),
    .pt128        (pt128),
    .pt192        (pt192),
    .pt256        (pt256),
    .results_ready(results_ready)
);

always #5 clk = ~clk;

integer pass_count = 0;
integer fail_count = 0;

initial begin
    $display("================================================");
    $display("  tb_aes_controller — Controller Unit Test");
    $display("================================================");
    $display("  Plaintext : %h", PT);
    $display("  Key128    : %h", K128);
    $display("  Key192    : %h", K192);
    $display("  Key256    : %h", K256);

    repeat (4) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);

    // Pulse pkt_valid for 1 cycle
    @(posedge clk);
    pkt_valid_r = 1'b1;
    @(posedge clk);
    pkt_valid_r = 1'b0;

    // Wait for results_ready
    @(posedge results_ready);
    @(posedge clk);

    $display("\n--- Encryption Results ---");
    $display("  CT128 (Mod V2) : %h", ct128);
    $display("  CT192 (Mod V2) : %h", ct192);
    $display("  CT256 (Mod V2) : %h", ct256);

    // Verify ciphertexts differ from standard AES
    if (ct128 !== STD_CT128) begin
        $display("  CT128 differs from standard AES: PASS"); pass_count = pass_count + 1;
    end else begin
        $display("  CT128 equals standard AES — modification inactive: FAIL"); fail_count = fail_count + 1;
    end
    if (ct192 !== STD_CT192) begin
        $display("  CT192 differs from standard AES: PASS"); pass_count = pass_count + 1;
    end else begin
        $display("  CT192 equals standard AES — modification inactive: FAIL"); fail_count = fail_count + 1;
    end
    if (ct256 !== STD_CT256) begin
        $display("  CT256 differs from standard AES: PASS"); pass_count = pass_count + 1;
    end else begin
        $display("  CT256 equals standard AES — modification inactive: FAIL"); fail_count = fail_count + 1;
    end

    $display("\n--- Decryption Results (round-trip) ---");
    $display("  PT128_rec : %h", pt128);
    $display("  PT192_rec : %h", pt192);
    $display("  PT256_rec : %h", pt256);
    $display("  Expected  : %h", PT);

    if (pt128 === PT) begin
        $display("  AES-128 round-trip: PASS"); pass_count = pass_count + 1;
    end else begin
        $display("  AES-128 round-trip: FAIL"); fail_count = fail_count + 1;
    end
    if (pt192 === PT) begin
        $display("  AES-192 round-trip: PASS"); pass_count = pass_count + 1;
    end else begin
        $display("  AES-192 round-trip: FAIL"); fail_count = fail_count + 1;
    end
    if (pt256 === PT) begin
        $display("  AES-256 round-trip: PASS"); pass_count = pass_count + 1;
    end else begin
        $display("  AES-256 round-trip: FAIL"); fail_count = fail_count + 1;
    end

    $display("\n================================================");
    $display("  PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("================================================\n");
    $finish;
end

initial begin
    #500_000;
    $display("TIMEOUT");
    $finish;
end

endmodule
