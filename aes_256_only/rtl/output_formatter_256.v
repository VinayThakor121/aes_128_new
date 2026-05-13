`timescale 1ns / 1ps
//
// output_formatter_256 — serialises AES-256 results over UART
//
// Sends 3 response frames in order:
//   Frame 0: ID=0x03 + orig_pt  (16B) + XOR checksum
//   Frame 1: ID=0x13 + ct256    (16B) + XOR checksum
//   Frame 2: ID=0x23 + pt256    (16B) + XOR checksum
//
// Each frame is 18 bytes.  Total response = 54 bytes.

module output_formatter_256 (
    input         clk,
    input         rst,
    input  [127:0] orig_pt,
    input  [127:0] ct256,
    input  [127:0] pt256,
    input         results_ready,
    output reg [7:0] tx_byte,
    output reg       tx_valid,
    input            tx_ready,
    output reg       tx_done
);

localparam [2:0] S_IDLE    = 3'd0,
                 S_TX_ID   = 3'd1,
                 S_TX_DATA = 3'd2,
                 S_TX_CHK  = 3'd3,
                 S_DONE    = 3'd4;
reg [2:0] state;
reg [1:0] result_idx;   // 0=orig_pt, 1=ct256, 2=pt256
reg [3:0] byte_cnt;
reg [7:0] chksum;
reg [127:0] tx_shift;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE; result_idx <= 0; byte_cnt <= 0; chksum <= 0; tx_shift <= 0;
        tx_byte <= 0; tx_valid <= 0; tx_done <= 0;
    end else begin
        tx_valid <= 1'b0; tx_done <= 1'b0;
        case (state)
            S_IDLE: if (results_ready) begin result_idx <= 2'd0; state <= S_TX_ID; end
            S_TX_ID: if (tx_ready) begin
                case (result_idx)
                    2'd0: begin tx_shift <= orig_pt; tx_byte <= 8'h03; end
                    2'd1: begin tx_shift <= ct256;   tx_byte <= 8'h13; end
                    2'd2: begin tx_shift <= pt256;   tx_byte <= 8'h23; end
                    default: begin tx_shift <= pt256; tx_byte <= 8'h23; end
                endcase
                tx_valid <= 1'b1; chksum <= 0; byte_cnt <= 0; state <= S_TX_DATA;
            end
            S_TX_DATA: if (tx_ready) begin
                tx_byte  <= tx_shift[127:120]; tx_valid <= 1'b1;
                chksum   <= chksum ^ tx_shift[127:120];
                tx_shift <= {tx_shift[119:0], 8'd0};
                if (byte_cnt == 4'd15) state <= S_TX_CHK;
                else byte_cnt <= byte_cnt + 4'd1;
            end
            S_TX_CHK: if (tx_ready) begin
                tx_byte <= chksum; tx_valid <= 1'b1;
                if (result_idx == 2'd2) state <= S_DONE;
                else begin result_idx <= result_idx + 2'd1; state <= S_TX_ID; end
            end
            S_DONE: begin tx_done <= 1'b1; state <= S_IDLE; end
            default: state <= S_IDLE;
        endcase
    end
end

endmodule
