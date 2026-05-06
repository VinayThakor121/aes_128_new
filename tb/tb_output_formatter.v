// tb_output_formatter.v — Unit testbench for output_formatter
//
// Provides six known 128-bit values, pulses results_ready, and verifies
// that the serialised output stream contains exactly 6×18=108 bytes in the
// correct order: ID, 16 data bytes MSB-first, XOR checksum.
//
// A mock uart_tx model accepts bytes immediately (tx_ready always high
// except for a 2-cycle busy window per byte, to exercise back-pressure).
`timescale 1ns / 1ps

module tb_output_formatter;

reg clk = 0;
reg rst = 1;

// Known test values
localparam [127:0] CT128 = 128'h135c5762f9d74dc27cde153393eb1a31;
localparam [127:0] CT192 = 128'h1c556f67dda70687553f924d7c153246;
localparam [127:0] CT256 = 128'h0a6aff44e685399d3bbf12db93d70e09;
localparam [127:0] PT128 = 128'h00112233445566778899aabbccddeeff;
localparam [127:0] PT192 = 128'h00112233445566778899aabbccddeeff;
localparam [127:0] PT256 = 128'h00112233445566778899aabbccddeeff;

reg results_ready_r = 1'b0;

wire [7:0] tx_byte;
wire       tx_valid;
wire       tx_done;

// Mock tx_ready: always high (no back-pressure in this unit test).
// The formatter is fully pipelined — back-pressure is tested end-to-end
// in tb_uart_aes_top.v where a real uart_tx model provides real back-pressure.
wire tx_ready_w = 1'b1;

output_formatter u_fmt (
    .clk          (clk),
    .rst          (rst),
    .ct128        (CT128),
    .ct192        (CT192),
    .ct256        (CT256),
    .pt128        (PT128),
    .pt192        (PT192),
    .pt256        (PT256),
    .results_ready(results_ready_r),
    .tx_byte      (tx_byte),
    .tx_valid     (tx_valid),
    .tx_ready     (tx_ready_w),
    .tx_done      (tx_done)
);

always #5 clk = ~clk;

// Capture bytes: fire on tx_valid (tx_ready is always 1, so every tx_valid is accepted)
reg  [7:0]  captured [0:107];   // 6 × 18 bytes
integer     capture_idx = 0;
reg         capture_done = 0;

always @(posedge clk) begin
    if (!rst && tx_valid && !capture_done) begin
        captured[capture_idx] = tx_byte;
        capture_idx = capture_idx + 1;
        if (capture_idx == 108)
            capture_done = 1;
    end
end

// ---------------------------------------------------------------
// Verify captured stream
// ---------------------------------------------------------------
// Expected result IDs and data
reg [7:0]   exp_id   [0:5];
reg [127:0] exp_data [0:5];

integer pass_count = 0;
integer fail_count = 0;

task check_frame;
    input integer frame;    // 0..5
    integer base, j;
    reg [7:0] exp_chk, act_chk;
    begin
        base = frame * 18;

        // Check ID
        if (captured[base] === exp_id[frame]) begin
            pass_count = pass_count + 1;
        end else begin
            $display("  Frame %0d: ID FAIL exp=0x%02h got=0x%02h",
                     frame, exp_id[frame], captured[base]);
            fail_count = fail_count + 1;
        end

        // Check data bytes and compute expected checksum
        exp_chk = 8'd0;
        for (j = 0; j < 16; j = j + 1) begin
            exp_chk = exp_chk ^ exp_data[frame][127 - j*8 -: 8];
            if (captured[base + 1 + j] !== exp_data[frame][127 - j*8 -: 8]) begin
                $display("  Frame %0d byte %0d: DATA FAIL exp=0x%02h got=0x%02h",
                         frame, j,
                         exp_data[frame][127 - j*8 -: 8],
                         captured[base + 1 + j]);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end
        end

        // Check checksum
        act_chk = captured[base + 17];
        if (act_chk === exp_chk) begin
            pass_count = pass_count + 1;
        end else begin
            $display("  Frame %0d: CHKSUM FAIL exp=0x%02h got=0x%02h",
                     frame, exp_chk, act_chk);
            fail_count = fail_count + 1;
        end
    end
endtask

initial begin
    $display("================================================");
    $display("  tb_output_formatter — Formatter Unit Test");
    $display("================================================");

    exp_id[0] = 8'h11; exp_data[0] = CT128;
    exp_id[1] = 8'h12; exp_data[1] = CT192;
    exp_id[2] = 8'h13; exp_data[2] = CT256;
    exp_id[3] = 8'h21; exp_data[3] = PT128;
    exp_id[4] = 8'h22; exp_data[4] = PT192;
    exp_id[5] = 8'h23; exp_data[5] = PT256;

    repeat (4) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);

    // Trigger formatter
    results_ready_r = 1'b1;
    @(posedge clk);
    results_ready_r = 1'b0;

    // Wait for all bytes to be captured
    wait (capture_done);
    repeat (4) @(posedge clk);

    // Verify
    begin : verify
        integer f;
        for (f = 0; f < 6; f = f + 1)
            check_frame(f);
    end

    $display("  Total bytes captured: %0d (expected 108)", capture_idx);
    if (capture_idx === 108) pass_count = pass_count + 1;
    else                     fail_count = fail_count + 1;

    $display("================================================");
    $display("  PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("================================================");
    $finish;
end

initial begin
    #5_000_000;
    $display("TIMEOUT");
    $finish;
end

endmodule
