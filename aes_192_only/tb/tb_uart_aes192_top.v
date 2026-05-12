`timescale 1ns / 1ps

module tb_uart_aes192_top;
localparam CLK_HZ  = 100_000_000;
localparam BAUD    = 250_000;
localparam BIT_CLK = CLK_HZ / BAUD;
localparam BIT_NS  = BIT_CLK * 10;

reg clk = 0;
reg rst = 1;
reg rx_sim = 1;
wire tx_wire;
wire [7:0] led;

uart_aes192_top #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_dut (
    .clk(clk), .rst(rst), .uart_rx_pin(rx_sim), .uart_tx_pin(tx_wire), .led(led)
);

always #5 clk = ~clk;

localparam [127:0] PT   = 128'h00112233445566778899aabbccddeeff;
localparam [191:0] K192 = 192'h000102030405060708090a0b0c0d0e0f1011121314151617;
localparam [127:0] REF_CT192 = 128'h1c556f67dda70687553f924d7c153246;

task send_uart_byte;
    input [7:0] b; integer i;
    begin
        rx_sim = 1'b0; #(BIT_NS);
        for (i = 0; i < 8; i = i + 1) begin rx_sim = b[i]; #(BIT_NS); end
        rx_sim = 1'b1; #(BIT_NS);
    end
endtask

reg [7:0] pkt [0:45];
integer j;
reg [7:0] chk;

task send_packet;
    integer k;
    begin
        pkt[0]=8'hAA; pkt[1]=8'h02; pkt[2]=8'h00; pkt[3]=8'h28;
        for (j=0;j<16;j=j+1) pkt[4+j]  = PT [127-j*8-:8];
        for (j=0;j<24;j=j+1) pkt[20+j] = K192[191-j*8-:8];
        chk = 8'd0;
        for (j=4;j<=43;j=j+1) chk = chk ^ pkt[j];
        pkt[44]=chk; pkt[45]=8'h55;
        for (k=0;k<46;k=k+1) send_uart_byte(pkt[k]);
    end
endtask

integer pass_cnt = 0;
integer fail_cnt = 0;
reg got_results = 0;
reg got_tx_done = 0;
wire results_ready_w = u_dut.u_ctrl.results_ready;
wire tx_done_w       = u_dut.u_fmt.tx_done;

always @(posedge clk) if (results_ready_w) got_results <= 1'b1;
always @(posedge clk) if (tx_done_w) got_tx_done <= 1'b1;

initial begin
    repeat (4) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);

    send_packet;
    wait (got_results);
    repeat (4) @(posedge clk);

    if (u_dut.u_ctrl.ct192 === REF_CT192) pass_cnt = pass_cnt + 1; else fail_cnt = fail_cnt + 1;
    if (u_dut.u_ctrl.pt192 === PT)        pass_cnt = pass_cnt + 1; else fail_cnt = fail_cnt + 1;

    wait (got_tx_done);
    $display("UART_AES192_ONLY PASS=%0d FAIL=%0d CT192=%h PT192=%h", pass_cnt, fail_cnt, u_dut.u_ctrl.ct192, u_dut.u_ctrl.pt192);
    $finish;
end

initial begin #20_000_000; $display("TIMEOUT"); $finish; end

endmodule
