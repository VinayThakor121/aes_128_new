// AES InvSubBytes: apply inverse S-box to every byte of the 128-bit state.
// FIPS-197 Section 5.3.2
`timescale 1ns / 1ps

module aes_inv_sub_bytes (
    input  [127:0] data_in,
    output [127:0] data_out
);

genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : inv_sbox_inst
        aes_sbox_inv u_isbox (
            .in_byte  (data_in [127 - 8*i -: 8]),
            .out_byte (data_out[127 - 8*i -: 8])
        );
    end
endgenerate

endmodule
