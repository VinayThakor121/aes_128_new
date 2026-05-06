`timescale 1ns / 1ps

module tb_AES128_ENCRYPT_ITERATIVE;

localparam [127:0] TEST_PLAINTEXT  = 128'h4142434445464748494a4b4c4d4e4f51;
localparam [127:0] TEST_KEY        = 128'h000102030405060708090a0b0c0d0e0f;
localparam [127:0] TEST_CIPHERTEXT = 128'h2682c7cc07bf0f585db9a92a5dedb25f;

reg clk = 1'b0;
reg [127:0] IN_DATA = TEST_PLAINTEXT;
reg [127:0] IN_KEY = TEST_KEY;
wire [127:0] OUT_DATA;

AES128_ENCRYPT_ITERATIVE dut (
    .clk(clk),
    .IN_DATA(IN_DATA),
    .IN_KEY(IN_KEY),
    .OUT_DATA(OUT_DATA)
);

always #5 clk = ~clk;

initial begin
    $display("Starting AES128_ENCRYPT_ITERATIVE simulation");
    repeat (120) @(posedge clk);

    $display("Plaintext           = %h", TEST_PLAINTEXT);
    $display("Key                 = %h", TEST_KEY);
    $display("Observed ciphertext = %h", OUT_DATA);
    $display("Expected ciphertext = %h", TEST_CIPHERTEXT);

    if (OUT_DATA !== TEST_CIPHERTEXT) begin
        $error("AES128_ENCRYPT_ITERATIVE mismatch");
    end else begin
        $display("AES128_ENCRYPT_ITERATIVE PASS");
    end

    repeat (4) @(posedge clk);
    $finish;
end

endmodule
