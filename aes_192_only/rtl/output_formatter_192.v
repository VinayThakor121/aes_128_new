`timescale 1ns / 1ps

module output_formatter_192 (
    input         clk,
    input         rst,
    input  [127:0] ct192,
    input  [127:0] pt192,
    input         results_ready,
    output reg [7:0] tx_byte,
    output reg       tx_valid,
    input            tx_ready,
    output reg       tx_done
);

localparam [2:0] S_IDLE=3'd0, S_TX_ID=3'd1, S_TX_DATA=3'd2, S_TX_CHK=3'd3, S_DONE=3'd4;
reg [2:0] state;
reg result_idx; //0 ct,1 pt
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
            S_IDLE: if (results_ready) begin result_idx <= 1'b0; state <= S_TX_ID; end
            S_TX_ID: if (tx_ready) begin
                tx_shift <= result_idx ? pt192 : ct192;
                tx_byte <= result_idx ? 8'h22 : 8'h12;
                tx_valid <= 1'b1; chksum <= 0; byte_cnt <= 0; state <= S_TX_DATA;
            end
            S_TX_DATA: if (tx_ready) begin
                tx_byte <= tx_shift[127:120]; tx_valid <= 1'b1;
                chksum <= chksum ^ tx_shift[127:120];
                tx_shift <= {tx_shift[119:0],8'd0};
                if (byte_cnt == 4'd15) state <= S_TX_CHK; else byte_cnt <= byte_cnt + 4'd1;
            end
            S_TX_CHK: if (tx_ready) begin
                tx_byte <= chksum; tx_valid <= 1'b1;
                if (result_idx) state <= S_DONE;
                else begin result_idx <= 1'b1; state <= S_TX_ID; end
            end
            S_DONE: begin tx_done <= 1'b1; state <= S_IDLE; end
            default: state <= S_IDLE;
        endcase
    end
end

endmodule
