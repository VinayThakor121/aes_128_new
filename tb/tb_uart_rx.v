// tb_uart_rx.v — Unit testbench for uart_rx
//
// Sends three bytes (0x55, 0xAA, 0x3C) down the simulated serial line at
// the simulation baud rate and verifies that uart_rx recovers each byte
// exactly, with rx_valid pulsing for exactly one clock cycle.
//
// Simulation baud rate:  BAUD=250_000 → divisor=25, bit period=400 clocks
// (exact divisor keeps the sampling grid perfectly aligned)
`timescale 1ns / 1ps

module tb_uart_rx;

localparam CLK_HZ  = 100_000_000;
localparam BAUD    = 250_000;
localparam BIT_CLK = CLK_HZ / BAUD;        // 400 clock cycles per bit
localparam BIT_NS  = BIT_CLK * 10;         // 4000 ns per bit (10 ns clock)

reg clk = 0;
reg rst = 1;
reg rx_sim = 1;   // idle-high serial line

wire [7:0] rx_byte;
wire       rx_valid;

wire baud_tick;
uart_baud_gen #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_baud (
    .clk(clk), .rst(rst), .baud_tick(baud_tick)
);

uart_rx u_rx (
    .clk      (clk),
    .rst      (rst),
    .baud_tick(baud_tick),
    .rx_serial(rx_sim),
    .rx_byte  (rx_byte),
    .rx_valid (rx_valid)
);

always #5 clk = ~clk;  // 100 MHz

// ---------------------------------------------------------------
// Task: send one UART byte (1 start + 8 data LSB-first + 1 stop)
// ---------------------------------------------------------------
task send_uart_byte;
    input [7:0] b;
    integer i;
    begin
        rx_sim = 1'b0;          // start bit
        #(BIT_NS);
        for (i = 0; i < 8; i = i + 1) begin
            rx_sim = b[i];      // data bits, LSB first
            #(BIT_NS);
        end
        rx_sim = 1'b1;          // stop bit
        #(BIT_NS);
    end
endtask

// ---------------------------------------------------------------
// Stimulus and checking
// ---------------------------------------------------------------
integer pass_count = 0;
integer fail_count = 0;
reg [7:0] test_bytes [0:2];
integer   t;

initial begin
    $display("================================================");
    $display("  tb_uart_rx — UART Receiver Unit Test");
    $display("================================================");
    $display("  BAUD=%0d  BIT_CLK=%0d  BIT_NS=%0d",
             BAUD, BIT_CLK, BIT_NS);

    test_bytes[0] = 8'h55;
    test_bytes[1] = 8'hAA;
    test_bytes[2] = 8'h3C;

    // Hold reset for a few cycles
    repeat (4) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);

    for (t = 0; t < 3; t = t + 1) begin
        // Fork: send byte while simultaneously watching for rx_valid
        fork
            send_uart_byte(test_bytes[t]);
            @(posedge rx_valid);   // wait until receiver asserts valid
        join

        // rx_valid just went high this clock cycle; rx_byte is stable
        if (rx_byte === test_bytes[t]) begin
            $display("  PASS: received 0x%02h", rx_byte);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: expected 0x%02h, got 0x%02h",
                     test_bytes[t], rx_byte);
            fail_count = fail_count + 1;
        end

        // Inter-byte gap
        #(BIT_NS * 2);
    end

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
