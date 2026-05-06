`timescale 1ns / 1ps

module INV_MIX_COLUMNS(
    input [127:0] IN_DATA,
    output [127:0] OUT_DATA
);

    // Function to multiply an 8-bit number by a small 4-bit constant in GF(2^8)
    function [7:0] gf_mul;
        input [7:0] a;
        input [3:0] b;
        reg [7:0] a2, a4, a8;
        begin
            // Multiply by 2
            a2 = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
            // Multiply by 4
            a4 = {a2[6:0], 1'b0} ^ (a2[7] ? 8'h1b : 8'h00);
            // Multiply by 8
            a8 = {a4[6:0], 1'b0} ^ (a4[7] ? 8'h1b : 8'h00);

            // Construct final multiplication mapping based on the constant 'b'
            gf_mul = 8'h00;
            if (b[0]) gf_mul = gf_mul ^ a;
            if (b[1]) gf_mul = gf_mul ^ a2;
            if (b[2]) gf_mul = gf_mul ^ a4;
            if (b[3]) gf_mul = gf_mul ^ a8;
        end
    endfunction

    // Process a single 32-bit column
    function [31:0] inv_mix_column_32;
        input [31:0] in_col;
        reg [7:0] s0, s1, s2, s3;
        begin
            s0 = in_col[31:24];
            s1 = in_col[23:16];
            s2 = in_col[15:8];
            s3 = in_col[7:0];

            inv_mix_column_32[31:24] = gf_mul(s0, 4'hE) ^ gf_mul(s1, 4'hB) ^ gf_mul(s2, 4'hD) ^ gf_mul(s3, 4'h9);
            inv_mix_column_32[23:16] = gf_mul(s0, 4'h9) ^ gf_mul(s1, 4'hE) ^ gf_mul(s2, 4'hB) ^ gf_mul(s3, 4'hD);
            inv_mix_column_32[15:8]  = gf_mul(s0, 4'hD) ^ gf_mul(s1, 4'h9) ^ gf_mul(s2, 4'hE) ^ gf_mul(s3, 4'hB);
            inv_mix_column_32[7:0]   = gf_mul(s0, 4'hB) ^ gf_mul(s1, 4'hD) ^ gf_mul(s2, 4'h9) ^ gf_mul(s3, 4'hE);
        end
    endfunction

    // Apply the function across all 4 columns independently
    assign OUT_DATA[127:96] = inv_mix_column_32(IN_DATA[127:96]);
    assign OUT_DATA[95:64]  = inv_mix_column_32(IN_DATA[95:64]);
    assign OUT_DATA[63:32]  = inv_mix_column_32(IN_DATA[63:32]);
    assign OUT_DATA[31:0]   = inv_mix_column_32(IN_DATA[31:0]);

endmodule