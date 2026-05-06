// tb_uart_tx.v — Unit testbench for uart_tx
//
// Requests transmission of three bytes (0xA5, 0x00, 0xFF) and decodes the
// resulting serial waveform by sampling at bit-centre intervals.
//
// Simulation baud rate:  BAUD=250_000 → divisor=25, bit period=400 clocks
`timescale 1ns / 1ps

module tb_uart_tx;

localparam CLK_HZ  = 100_000_000;
localparam BAUD    = 250_000;
localparam BIT_CLK = CLK_HZ / BAUD;        // 400 clock cycles per bit
localparam BIT_NS  = BIT_CLK * 10;         // 4000 ns per bit (10 ns clock)

reg clk = 0;
reg rst = 1;
reg [7:0] tx_byte_r = 8'd0;
reg       tx_valid_r = 1'b0;

wire tx_serial;
wire tx_ready;
wire baud_tick;

uart_baud_gen #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_baud (
    .clk(clk), .rst(rst), .baud_tick(baud_tick)
);

uart_tx u_tx (
    .clk      (clk),
    .rst      (rst),
    .baud_tick(baud_tick),
    .tx_byte  (tx_byte_r),
    .tx_valid (tx_valid_r),
    .tx_serial(tx_serial),
    .tx_ready (tx_ready)
);

always #5 clk = ~clk;  // 100 MHz

// ---------------------------------------------------------------
// Task: request one byte and sample the serial output
// ---------------------------------------------------------------
task send_and_decode;
    input  [7:0] send_byte;
    output [7:0] decoded_byte;
    integer i;
    reg     sbit;
    begin
        // Wait until transmitter is ready
        wait (tx_ready);
        @(posedge clk);

        // Assert tx_valid for 1 cycle
        tx_byte_r  = send_byte;
        tx_valid_r = 1'b1;
        @(posedge clk);
        tx_valid_r = 1'b0;

        // Wait for start bit (falling edge on tx_serial)
        @(negedge tx_serial);

        // Skip to bit-centre of start bit
        #(BIT_NS / 2);

        // Verify start bit is still 0
        if (tx_serial !== 1'b0)
            $display("  WARNING: start bit not 0");

        // Sample 8 data bits at their centres
        for (i = 0; i < 8; i = i + 1) begin
            #(BIT_NS);
            decoded_byte[i] = tx_serial;   // LSB first
        end

        // Wait for stop bit
        #(BIT_NS);
    end
endtask

// ---------------------------------------------------------------
// Stimulus and checking
// ---------------------------------------------------------------
integer pass_count = 0;
integer fail_count = 0;
reg [7:0] test_bytes [0:2];
reg [7:0] recv;
integer t;

initial begin
    $display("================================================");
    $display("  tb_uart_tx — UART Transmitter Unit Test");
    $display("================================================");

    test_bytes[0] = 8'hA5;
    test_bytes[1] = 8'h00;
    test_bytes[2] = 8'hFF;

    repeat (4) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);

    for (t = 0; t < 3; t = t + 1) begin
        send_and_decode(test_bytes[t], recv);
        if (recv === test_bytes[t]) begin
            $display("  PASS: sent 0x%02h, decoded 0x%02h", test_bytes[t], recv);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: sent 0x%02h, decoded 0x%02h", test_bytes[t], recv);
            fail_count = fail_count + 1;
        end
    end

    $display("================================================");
    $display("  PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("================================================");
    $finish;
end

initial begin
    #10_000_000;
    $display("TIMEOUT");
    $finish;
end

endmodule
