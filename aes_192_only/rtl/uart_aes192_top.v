`timescale 1ns / 1ps

module uart_aes192_top #(
    parameter CLK_HZ = 100_000_000,
    parameter BAUD   = 115_200
) (
    input  clk,
    input  rst,
    input  uart_rx_pin,
    output uart_tx_pin,
    output [7:0] led
);

wire baud_tick;
uart_baud_gen #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_baud (.clk(clk), .rst(rst), .baud_tick(baud_tick));

wire [7:0] rx_byte;
wire rx_valid;
uart_rx u_rx (.clk(clk), .rst(rst), .baud_tick(baud_tick), .rx_serial(uart_rx_pin), .rx_byte(rx_byte), .rx_valid(rx_valid));

wire [127:0] plaintext;
wire [191:0] key192;
wire pkt_valid, pkt_error;
packet_decoder_192 u_pkt (
    .clk(clk), .rst(rst), .rx_byte(rx_byte), .rx_valid(rx_valid),
    .plaintext(plaintext), .key192(key192), .pkt_valid(pkt_valid), .pkt_error(pkt_error)
);

wire [127:0] ct192, pt192;
wire results_ready;
aes_controller_192 u_ctrl (
    .clk(clk), .rst(rst), .plaintext(plaintext), .key192(key192), .pkt_valid(pkt_valid),
    .ct192(ct192), .pt192(pt192), .results_ready(results_ready)
);

wire [7:0] tx_byte;
wire tx_valid, tx_ready;
uart_tx u_tx (.clk(clk), .rst(rst), .baud_tick(baud_tick), .tx_byte(tx_byte), .tx_valid(tx_valid), .tx_serial(uart_tx_pin), .tx_ready(tx_ready));

wire tx_done;
output_formatter_192 u_fmt (
    .clk(clk), .rst(rst), .ct192(ct192), .pt192(pt192), .results_ready(results_ready),
    .tx_byte(tx_byte), .tx_valid(tx_valid), .tx_ready(tx_ready), .tx_done(tx_done)
);

reg [7:0] led_r;
always @(posedge clk or posedge rst) begin
    if (rst) led_r <= 8'd0;
    else begin
        if (pkt_valid)     led_r[0] <= 1'b1;
        if (pkt_error)     led_r[1] <= 1'b1;
        if (results_ready) led_r[2] <= 1'b1;
        if (tx_done)       led_r[3] <= 1'b1;
        if (pkt_valid)     led_r[3:1] <= 3'b0;
    end
end
assign led = led_r;

endmodule
