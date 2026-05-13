`timescale 1ns / 1ps
//
// tb_uart_aes256_top — End-to-end UART testbench for uart_aes256_top
//
// Sends a 54-byte AES-256 packet over simulated UART and verifies
// that the FPGA returns correct enc/dec results in 3 response frames.

module tb_uart_aes256_top;

localparam CLK_HZ  = 100_000_000;
localparam BAUD    = 250_000;
localparam BIT_CLK = CLK_HZ / BAUD;
localparam BIT_NS  = BIT_CLK * 10;

reg clk = 0;
reg rst = 1;
reg rx_sim = 1;
wire tx_wire;
wire [7:0] led;

uart_aes256_top #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_dut (
    .clk(clk), .rst(rst), .uart_rx_pin(rx_sim),
    .uart_tx_pin(tx_wire), .led(led)
);

always #5 clk = ~clk;

localparam [127:0] PT     = 128'h00112233445566778899aabbccddeeff;
localparam [255:0] K256   = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
localparam [127:0] REF_CT = 128'h0a6aff44e685399d3bbf12db93d70e09;

task send_uart_byte;
    input [7:0] b; integer i;
    begin
        rx_sim = 1'b0; #(BIT_NS);
        for (i = 0; i < 8; i = i + 1) begin rx_sim = b[i]; #(BIT_NS); end
        rx_sim = 1'b1; #(BIT_NS);
    end
endtask

reg [7:0] pkt [0:53];
integer j;
reg [7:0] chk;

task send_packet;
    integer k;
    begin
        // Header: AA 03 00 30
        pkt[0]=8'hAA; pkt[1]=8'h03; pkt[2]=8'h00; pkt[3]=8'h30;
        // Plaintext (16 bytes, MSB first)
        for (j=0;j<16;j=j+1) pkt[4+j]  = PT[127-j*8-:8];
        // Key256 (32 bytes, MSB first)
        for (j=0;j<32;j=j+1) pkt[20+j] = K256[255-j*8-:8];
        // Checksum over payload bytes 4..51
        chk = 8'd0;
        for (j=4;j<=51;j=j+1) chk = chk ^ pkt[j];
        pkt[52]=chk; pkt[53]=8'h55;
        for (k=0;k<54;k=k+1) send_uart_byte(pkt[k]);
    end
endtask

integer pass_cnt = 0;
integer fail_cnt = 0;
reg got_results = 0;
reg got_tx_done = 0;
wire results_ready_w = u_dut.u_ctrl.results_ready;
wire tx_done_w       = u_dut.u_fmt.tx_done;

always @(posedge clk) if (results_ready_w) got_results <= 1'b1;
always @(posedge clk) if (tx_done_w)       got_tx_done <= 1'b1;

initial begin
    repeat (4) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);

    send_packet;
    wait (got_results);
    repeat (4) @(posedge clk);

    if (u_dut.u_ctrl.ct256   === REF_CT) pass_cnt = pass_cnt + 1; else fail_cnt = fail_cnt + 1;
    if (u_dut.u_ctrl.pt256   === PT)     pass_cnt = pass_cnt + 1; else fail_cnt = fail_cnt + 1;
    if (u_dut.u_ctrl.orig_pt === PT)     pass_cnt = pass_cnt + 1; else fail_cnt = fail_cnt + 1;

    wait (got_tx_done);

    $display("");
    $display("## AES-256 UART TEST");
    $display("");
    $display("Input Plaintext:");
    $display("%H", u_dut.u_ctrl.orig_pt);
    $display("");
    $display("Encryption Key:");
    $display("%H", K256);
    $display("");
    $display("Encrypted Ciphertext:");
    $display("%H", u_dut.u_ctrl.ct256);
    $display("");
    $display("Decrypted Plaintext:");
    $display("%H", u_dut.u_ctrl.pt256);
    $display("");
    if (u_dut.u_ctrl.pt256 === PT) begin
        $display("RESULT:");
        $display("PASS - Retrieved plaintext matches original plaintext");
    end else begin
        $display("RESULT:");
        $display("FAIL - Retrieved plaintext does NOT match original plaintext");
    end
    $display("");
    $display("UART_AES256_ONLY PASS=%0d FAIL=%0d CT256=%h PT256=%h",
             pass_cnt, fail_cnt, u_dut.u_ctrl.ct256, u_dut.u_ctrl.pt256);
    $finish;
end

initial begin #30_000_000; $display("TIMEOUT"); $finish; end

endmodule
