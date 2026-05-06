// AES InvShiftRows: cyclically shift rows of the state to the right.
// FIPS-197 Section 5.3.1
//
// Row 0: no shift
// Row 1: shift right by 1  (inverse of shift-left-1)
// Row 2: shift right by 2  (inverse of shift-left-2)
// Row 3: shift right by 3  (inverse of shift-left-3)
`timescale 1ns / 1ps

module aes_inv_shift_rows (
    input  [127:0] data_in,
    output [127:0] data_out
);

// Row 0 (bytes 0,4,8,12): no shift
assign data_out[127:120] = data_in[127:120];
assign data_out[ 95: 88] = data_in[ 95: 88];
assign data_out[ 63: 56] = data_in[ 63: 56];
assign data_out[ 31: 24] = data_in[ 31: 24];

// Row 1 (bytes 1,5,9,13): shift right 1  ->  new order: 13,1,5,9
assign data_out[119:112] = data_in[ 23: 16];
assign data_out[ 87: 80] = data_in[119:112];
assign data_out[ 55: 48] = data_in[ 87: 80];
assign data_out[ 23: 16] = data_in[ 55: 48];

// Row 2 (bytes 2,6,10,14): shift right 2  ->  new order: 10,14,2,6
assign data_out[111:104] = data_in[ 47: 40];
assign data_out[ 79: 72] = data_in[ 15:  8];
assign data_out[ 47: 40] = data_in[111:104];
assign data_out[ 15:  8] = data_in[ 79: 72];

// Row 3 (bytes 3,7,11,15): shift right 3  ->  new order: 7,11,15,3
assign data_out[103: 96] = data_in[ 71: 64];
assign data_out[ 71: 64] = data_in[ 39: 32];
assign data_out[ 39: 32] = data_in[  7:  0];
assign data_out[  7:  0] = data_in[103: 96];

endmodule
