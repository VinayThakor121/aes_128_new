// tb_packet_decoder.v — Unit testbench for packet_decoder
//
// Builds a valid 94-byte packet using NIST FIPS-197 Appendix C test vectors,
// feeds it one byte at a time via simulated rx_valid pulses, and verifies
// that pkt_valid pulses and all decoded fields match.
// A second run injects a corrupted checksum and verifies pkt_error fires.
`timescale 1ns / 1ps

module tb_packet_decoder;

reg clk = 0;
reg rst = 1;
reg [7:0] rx_byte_r = 8'd0;
reg       rx_valid_r = 1'b0;

wire [127:0] plaintext, key128;
wire [191:0] key192;
wire [255:0] key256;
wire         pkt_valid, pkt_error;

packet_decoder u_dec (
    .clk      (clk),
    .rst      (rst),
    .rx_byte  (rx_byte_r),
    .rx_valid (rx_valid_r),
    .plaintext(plaintext),
    .key128   (key128),
    .key192   (key192),
    .key256   (key256),
    .pkt_valid(pkt_valid),
    .pkt_error(pkt_error)
);

always #5 clk = ~clk;  // 100 MHz

// ---------------------------------------------------------------
// NIST FIPS-197 test vectors (same as the existing AES testbenches)
// ---------------------------------------------------------------
localparam [127:0] PT   = 128'h00112233445566778899aabbccddeeff;
localparam [127:0] K128 = 128'h000102030405060708090a0b0c0d0e0f;
localparam [191:0] K192 = 192'h000102030405060708090a0b0c0d0e0f1011121314151617;
localparam [255:0] K256 = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;

// ---------------------------------------------------------------
// Task: send one byte with a 1-cycle rx_valid pulse
// ---------------------------------------------------------------
task send_byte;
    input [7:0] b;
    begin
        @(posedge clk);
        rx_byte_r  = b;
        rx_valid_r = 1'b1;
        @(posedge clk);
        rx_valid_r = 1'b0;
    end
endtask

// ---------------------------------------------------------------
// Build packet into a flat byte array and send it
// ---------------------------------------------------------------
reg [7:0] pkt [0:93];
integer i;
reg [7:0] chk;

task build_and_send_packet;
    input corrupt_checksum;
    integer j, k;
    begin
        // Header
        pkt[0] = 8'hAA;
        pkt[1] = 8'h01;
        pkt[2] = 8'h00;
        pkt[3] = 8'h58;

        // Plaintext (16 bytes MSB first)
        for (j = 0; j < 16; j = j + 1)
            pkt[4 + j] = PT[127 - j*8 -: 8];

        // Key128 (16 bytes MSB first)
        for (j = 0; j < 16; j = j + 1)
            pkt[20 + j] = K128[127 - j*8 -: 8];

        // Key192 (24 bytes MSB first)
        for (j = 0; j < 24; j = j + 1)
            pkt[36 + j] = K192[191 - j*8 -: 8];

        // Key256 (32 bytes MSB first)
        for (j = 0; j < 32; j = j + 1)
            pkt[60 + j] = K256[255 - j*8 -: 8];

        // Compute XOR checksum over payload (bytes 4..91)
        chk = 8'd0;
        for (j = 4; j <= 91; j = j + 1)
            chk = chk ^ pkt[j];

        pkt[92] = corrupt_checksum ? (chk ^ 8'hFF) : chk;
        pkt[93] = 8'h55;

        // Send all 94 bytes
        for (k = 0; k < 94; k = k + 1)
            send_byte(pkt[k]);
    end
endtask

// ---------------------------------------------------------------
// Latch 1-cycle pulses so the initial block can check them
// ---------------------------------------------------------------
reg pkt_valid_seen;
reg pkt_error_seen;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pkt_valid_seen <= 1'b0;
        pkt_error_seen <= 1'b0;
    end else begin
        if (pkt_valid) pkt_valid_seen <= 1'b1;
        if (pkt_error) pkt_error_seen <= 1'b1;
    end
end

// ---------------------------------------------------------------
// Stimulus
// ---------------------------------------------------------------
integer pass_count = 0;
integer fail_count = 0;

initial begin
    $display("================================================");
    $display("  tb_packet_decoder — Packet Parser Unit Test");
    $display("================================================");

    repeat (4) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);

    // ---- Test 1: valid packet ----
    $display("\n--- Test 1: valid packet ---");
    build_and_send_packet(0);
    // Give one more clock for the pulse to propagate and be latched
    repeat (2) @(posedge clk);

    if (pkt_valid_seen) begin
        $display("  pkt_valid asserted: PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  pkt_valid NOT asserted: FAIL");
        fail_count = fail_count + 1;
    end

    if (plaintext === PT) begin
        $display("  plaintext match: PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  plaintext MISMATCH: expected %h got %h", PT, plaintext);
        fail_count = fail_count + 1;
    end

    if (key128 === K128) begin
        $display("  key128 match: PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  key128 MISMATCH: expected %h got %h", K128, key128);
        fail_count = fail_count + 1;
    end

    if (key192 === K192) begin
        $display("  key192 match: PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  key192 MISMATCH: expected %h got %h", K192, key192);
        fail_count = fail_count + 1;
    end

    if (key256 === K256) begin
        $display("  key256 match: PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  key256 MISMATCH: expected %h got %h", K256, key256);
        fail_count = fail_count + 1;
    end

    // Gap between packets; clear latches via reset then re-enable
    @(posedge clk); rst = 1; @(posedge clk); rst = 0;
    repeat (2) @(posedge clk);

    // ---- Test 2: corrupted checksum ----
    $display("\n--- Test 2: corrupted checksum ---");
    build_and_send_packet(1);
    repeat (2) @(posedge clk);

    if (pkt_error_seen && !pkt_valid_seen) begin
        $display("  pkt_error asserted (checksum rejected): PASS");
        pass_count = pass_count + 1;
    end else begin
        $display("  Expected pkt_error, got valid=%0b error=%0b: FAIL",
                 pkt_valid_seen, pkt_error_seen);
        fail_count = fail_count + 1;
    end

    repeat (4) @(posedge clk);

    $display("\n================================================");
    $display("  PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("================================================\n");
    $finish;
end

initial begin
    #50_000_000;
    $display("TIMEOUT");
    $finish;
end

endmodule
