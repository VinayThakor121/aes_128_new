// AES ShiftRows: cyclically shift rows of the state to the left.
// FIPS-197 Section 5.1.2
//
// State layout (column-major, MSB-first in 128-bit vector):
//   byte 0  = data[127:120]  state[row=0, col=0]
//   byte 1  = data[119:112]  state[row=1, col=0]
//   byte 2  = data[111:104]  state[row=2, col=0]
//   byte 3  = data[103: 96]  state[row=3, col=0]
//   byte 4  = data[ 95: 88]  state[row=0, col=1]
//   ...
//
// Row 0: no shift
// Row 1: shift left by 1
// Row 2: shift left by 2
// Row 3: shift left by 3
`timescale 1ns / 1ps

module aes_shift_rows (
    input  [127:0] data_in,
    output [127:0] data_out
);

// Row 0 (bytes 0,4,8,12): no shift
assign data_out[127:120] = data_in[127:120];
assign data_out[ 95: 88] = data_in[ 95: 88];
assign data_out[ 63: 56] = data_in[ 63: 56];
assign data_out[ 31: 24] = data_in[ 31: 24];

// Row 1 (bytes 1,5,9,13): shift left 1  ->  new order: 5,9,13,1
assign data_out[119:112] = data_in[ 87: 80];
assign data_out[ 87: 80] = data_in[ 55: 48];
assign data_out[ 55: 48] = data_in[ 23: 16];
assign data_out[ 23: 16] = data_in[119:112];

// Row 2 (bytes 2,6,10,14): shift left 2  ->  new order: 10,14,2,6
assign data_out[111:104] = data_in[ 47: 40];
assign data_out[ 79: 72] = data_in[ 15:  8];
assign data_out[ 47: 40] = data_in[111:104];
assign data_out[ 15:  8] = data_in[ 79: 72];

// Row 3 (bytes 3,7,11,15): shift left 3  ->  new order: 15,3,7,11
assign data_out[103: 96] = data_in[  7:  0];
assign data_out[ 71: 64] = data_in[103: 96];
assign data_out[ 39: 32] = data_in[ 71: 64];
assign data_out[  7:  0] = data_in[ 39: 32];

endmodule
