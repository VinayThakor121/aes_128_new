`timescale 1ns/1ps
module tb_uart;

    reg        clk      = 0;
    reg        rx       = 1;
    wire       tx;
    wire [7:0] rx_data;
    wire       rx_done;
    reg  [7:0] tx_data  = 8'h00;
    reg        tx_start = 0;
    wire       tx_busy;

    // 100 MHz clock
    always #5 clk = ~clk;

    // UART RX instance
    uart_rx #(.CLKS_PER_BIT(16)) RX (
        .clk      (clk),
        .rx       (rx),
        .data_out (rx_data),
        .done     (rx_done)
    );

    // UART TX instance
    uart_tx #(.CLKS_PER_BIT(16)) TX (
        .clk      (clk),
        .start    (tx_start),
        .data_in  (tx_data),
        .tx       (tx),
        .busy     (tx_busy)
    );

    // Send byte task - 16 clocks per bit @ 100MHz = 160ns per bit
    task send_byte(input [7:0] data);
        integer i;
        begin
            rx = 1;
            #160;
            // Start bit
            rx = 0;
            #160;
            // Data bits LSB first
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #160;
            end
            // Stop bit
            rx = 1;
            #160;
        end
    endtask

    initial begin
        tx_start = 0;
        tx_data  = 8'h00;
        #200;

        // Test RX: send 0xA5, expect rx_data = 0xA5
        send_byte(8'hA5);
        #2000;

        // Test TX: transmit 0x3C, watch tx line
        tx_data  = 8'h3C;
        tx_start = 1;
        #10;
        tx_start = 0;
        #5000;

        $finish;
    end

endmodule