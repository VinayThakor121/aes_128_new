`timescale 1ns/1ps

module tb_top;

reg clk = 0;
reg rst = 0;
reg rx  = 1;
wire tx;

localparam integer CLKS_PER_BIT = 868;
localparam integer CLK_PERIOD_NS = 10;
localparam integer UART_BIT_TIME_NS = CLKS_PER_BIT * CLK_PERIOD_NS;

// Clock (100 MHz)
always #5 clk = ~clk;

// DUT
top_aes_uart DUT (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .tx(tx)
);

// =====================================================
// UART SEND TASK
// =====================================================
task send_byte(input [7:0] data);
    integer i;
    begin
        rx = 1; #(UART_BIT_TIME_NS);        // idle

        rx = 0; #(UART_BIT_TIME_NS);        // start bit

        for (i = 0; i < 8; i = i + 1) begin
            rx = data[i];    // LSB first
            #(UART_BIT_TIME_NS);
        end

        rx = 1; #(UART_BIT_TIME_NS);        // stop bit
    end
endtask

// =====================================================
// TEST DATA
// =====================================================
integer i;

reg [7:0] cipher [0:15];
reg [7:0] key [0:15];

initial begin

    // Reset
    rst = 1;
    #100;
    rst = 0;

    // ================= CIPHER (YOUR VECTOR) =================
    cipher[0]=8'hc8; cipher[1]=8'hf7; cipher[2]=8'hd4; cipher[3]=8'h3c;
    cipher[4]=8'hd9; cipher[5]=8'h8f; cipher[6]=8'h2e; cipher[7]=8'h5a;
    cipher[8]=8'he1; cipher[9]=8'h10; cipher[10]=8'h01; cipher[11]=8'h07;
    cipher[12]=8'h71; cipher[13]=8'h70; cipher[14]=8'h58; cipher[15]=8'h71;

    // ================= KEY =================
    key[0]=8'h00; key[1]=8'h01; key[2]=8'h02; key[3]=8'h03;
    key[4]=8'h04; key[5]=8'h05; key[6]=8'h06; key[7]=8'h07;
    key[8]=8'h08; key[9]=8'h09; key[10]=8'h0a; key[11]=8'h0b;
    key[12]=8'h0c; key[13]=8'h0d; key[14]=8'h0e; key[15]=8'h0f;

    #1000;

    // ================= SEND CIPHER =================
    for (i = 0; i < 16; i = i + 1) begin
        send_byte(cipher[i]);
        #200;
    end

    // ================= SEND KEY =================
    for (i = 0; i < 16; i = i + 1) begin
        send_byte(key[i]);
        #200;
    end

    // ================= WAIT =================
    #1500000;

    // ================= RESULT =================
    $display("\n=========== FINAL RESULT ===========");
    $display("DATA (Cipher) = %h", DUT.data_reg);
    $display("KEY           = %h", DUT.key_reg);
    $display("AES OUTPUT    = %h", DUT.aes_out);

    if (DUT.aes_out == 128'h4142434445464748494a4b4c4d4e4f52)
        $display(" DECRYPTION SUCCESS");
    else
        $display(" DECRYPTION FAILED");

    $display("====================================\n");

    $finish;
end

endmodule
