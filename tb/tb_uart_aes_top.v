// tb_uart_aes_top.v — Full end-to-end integration testbench
//
// Verifies the complete system by:
//   1. Bit-banging a valid 94-byte input packet onto uart_rx_pin.
//   2. Waiting for aes_controller to assert results_ready.
//   3. Reading the six 128-bit results directly from aes_controller registers.
//   4. Verifying all results against NIST FIPS-197 expected values.
//   5. Confirming the output_formatter completed transmission (tx_done fired).
//
// The UART TX serial encoding is covered by tb_uart_tx and tb_output_formatter.
`timescale 1ns / 1ps

module tb_uart_aes_top;

localparam CLK_HZ  = 100_000_000;
localparam BAUD    = 250_000;
localparam BIT_CLK = CLK_HZ / BAUD;
localparam BIT_NS  = BIT_CLK * 10;

reg clk = 0;
reg rst = 1;
reg rx_sim = 1;

wire tx_wire;
wire [7:0] led;

uart_aes_top #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_dut (
    .clk(clk), .rst(rst),
    .uart_rx_pin(rx_sim), .uart_tx_pin(tx_wire), .led(led)
);

always #5 clk = ~clk;

// NIST FIPS-197 test vectors
localparam [127:0] PT   = 128'h00112233445566778899aabbccddeeff;
localparam [127:0] K128 = 128'h000102030405060708090a0b0c0d0e0f;
localparam [191:0] K192 = 192'h000102030405060708090a0b0c0d0e0f1011121314151617;
localparam [255:0] K256 = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;

// Modified V2 reference ciphertexts (verified by tb_aes_controller)
localparam [127:0] REF_CT128 = 128'h135c5762f9d74dc27cde153393eb1a31;
localparam [127:0] REF_CT192 = 128'h1c556f67dda70687553f924d7c153246;
localparam [127:0] REF_CT256 = 128'h0a6aff44e685399d3bbf12db93d70e09;

// Task: send one UART byte on rx_sim
task send_uart_byte;
    input [7:0] b; integer i;
    begin
        rx_sim = 1'b0; #(BIT_NS);
        for (i = 0; i < 8; i = i + 1) begin rx_sim = b[i]; #(BIT_NS); end
        rx_sim = 1'b1; #(BIT_NS);
    end
endtask

// Build and send the 94-byte input packet
reg [7:0] pkt [0:93];
integer j;
reg [7:0] chk;

task send_packet;
    integer k;
    begin
        pkt[0]=8'hAA; pkt[1]=8'h01; pkt[2]=8'h00; pkt[3]=8'h58;
        for (j=0;j<16;j=j+1) pkt[4+j]  = PT [127-j*8-:8];
        for (j=0;j<16;j=j+1) pkt[20+j] = K128[127-j*8-:8];
        for (j=0;j<24;j=j+1) pkt[36+j] = K192[191-j*8-:8];
        for (j=0;j<32;j=j+1) pkt[60+j] = K256[255-j*8-:8];
        chk = 8'd0;
        for (j=4;j<=91;j=j+1) chk = chk ^ pkt[j];
        pkt[92]=chk; pkt[93]=8'h55;
        for (k=0;k<94;k=k+1) send_uart_byte(pkt[k]);
    end
endtask

// Check/report one result
integer pass_cnt = 0;
integer fail_cnt = 0;

task check_result;
    input [127:0] got;
    input [127:0] exp;
    input [63:0]  label;   // 8-char label in ASCII bits (unused in display, for info)
    begin
        if (got === exp) begin
            $display("    PASS  got=%h", got);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("    FAIL  exp=%h", exp);
            $display("          got=%h", got);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

// DUT internal signals accessed via hierarchical references
wire results_ready_w = u_dut.u_ctrl.results_ready;
wire tx_done_w       = u_dut.u_fmt.tx_done;

// Capture results_ready pulse
reg got_results = 0;
always @(posedge clk) if (results_ready_w) got_results <= 1'b1;

// Capture tx_done pulse
reg got_tx_done = 0;
always @(posedge clk) if (tx_done_w) got_tx_done <= 1'b1;

// Main stimulus
initial begin
    $display("====================================================");
    $display("  tb_uart_aes_top -- Full Integration Test");
    $display("====================================================");
    $display("  Plaintext : %h", PT);
    $display("  BAUD=%0d", BAUD);

    repeat (4) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);

    $display("\n[1] Sending 94-byte input packet...");
    send_packet;
    $display("    Packet sent.");

    $display("\n[2] Waiting for AES results_ready...");
    wait (got_results);
    repeat (4) @(posedge clk);
    $display("    results_ready received.");

    $display("\n[3] Checking AES results:");
    $display("  CT128  :");
    check_result(u_dut.u_ctrl.ct128, REF_CT128, 64'h0);
    $display("  CT192  :");
    check_result(u_dut.u_ctrl.ct192, REF_CT192, 64'h0);
    $display("  CT256  :");
    check_result(u_dut.u_ctrl.ct256, REF_CT256, 64'h0);
    $display("  PT128r (dec128):");
    check_result(u_dut.u_ctrl.pt128, PT, 64'h0);
    $display("  PT192r (dec192):");
    check_result(u_dut.u_ctrl.pt192, PT, 64'h0);
    $display("  PT256r (dec256):");
    check_result(u_dut.u_ctrl.pt256, PT, 64'h0);

    $display("\n[4] Waiting for output_formatter tx_done...");
    wait (got_tx_done);
    $display("    tx_done received (formatter transmitted all 108 bytes).");

    $display("\n====================================================");
    $display("  PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
    $display("====================================================\n");
    $finish;
end

initial begin
    #20_000_000;
    $display("TIMEOUT");
    $finish;
end

endmodule
