`timescale 1ns / 1ps

module testbench;

reg clk;
reg [127:0] cipher;
reg [127:0] key;

wire [127:0] out;

// DUT
AES128_DECRYPT_STAGE4 DUT(
    .clk(clk),
    .IN_DATA(cipher),
    .IN_KEY(key),
    .OUT_DATA(out)
);

// Clock
always #5 clk = ~clk;

initial begin
    clk = 0;

    // Input test vector
    cipher = 128'h3196de4d672d06a0d52d947ae3eea789;
    key    = 128'h000102030405060708090a0b0c0d0e0f;

    #10000;

    $display("\n========= FINAL OUTPUT =========");
    $display("Plaintext Got = %h", out);

    if(out == 128'h4142434445464748494a4b4c4d4e4f54)
        $display("✅ DECRYPTION SUCCESS");
    else
        $display("❌ DECRYPTION FAILED");

    $finish;
end

endmodule