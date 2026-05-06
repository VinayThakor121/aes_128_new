`timescale 1ns / 1ps

module INV_SUB_BYTES(
    input [127:0] IN_DATA,
    output [127:0] OUT_DATA
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : inv_sbox_loop
            inv_substitution_box isbox (
                .in_byte(IN_DATA[(i*8)+7 : i*8]),
                .out_byte(OUT_DATA[(i*8)+7 : i*8])
            );
        end
    endgenerate
endmodule