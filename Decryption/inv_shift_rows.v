`timescale 1ns / 1ps

module INV_SHIFT_ROWS(
    input [127:0] IN_DATA,
    output [127:0] OUT_DATA
);
    // Row 0: No shift
    assign OUT_DATA[127:120] = IN_DATA[127:120];
    assign OUT_DATA[95:88]   = IN_DATA[95:88];
    assign OUT_DATA[63:56]   = IN_DATA[63:56];
    assign OUT_DATA[31:24]   = IN_DATA[31:24];

    // Row 1: Shift right by 1 byte
    assign OUT_DATA[119:112] = IN_DATA[23:16];
    assign OUT_DATA[87:80]   = IN_DATA[119:112];
    assign OUT_DATA[55:48]   = IN_DATA[87:80];
    assign OUT_DATA[23:16]   = IN_DATA[55:48];

    // Row 2: Shift right by 2 bytes
    assign OUT_DATA[111:104] = IN_DATA[47:40];
    assign OUT_DATA[79:72]   = IN_DATA[15:8];
    assign OUT_DATA[47:40]   = IN_DATA[111:104];
    assign OUT_DATA[15:8]    = IN_DATA[79:72];

    // Row 3: Shift right by 3 bytes
    assign OUT_DATA[103:96]  = IN_DATA[71:64];
    assign OUT_DATA[71:64]   = IN_DATA[39:32];
    assign OUT_DATA[39:32]   = IN_DATA[7:0];
    assign OUT_DATA[7:0]     = IN_DATA[103:96];
endmodule