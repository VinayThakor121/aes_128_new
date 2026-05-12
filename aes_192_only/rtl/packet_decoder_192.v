`timescale 1ns / 1ps

module packet_decoder_192 (
    input         clk,
    input         rst,
    input  [7:0]  rx_byte,
    input         rx_valid,
    output reg [127:0] plaintext,
    output reg [191:0] key192,
    output reg         pkt_valid,
    output reg         pkt_error
);

localparam [2:0] S_WAIT_START=3'd0, S_CHECK_CMD=3'd1, S_RX_LEN_H=3'd2,
                 S_RX_LEN_L=3'd3, S_RX_PAYLOAD=3'd4, S_RX_CHK=3'd5, S_WAIT_END=3'd6;
reg [2:0] state;
reg [5:0] payload_cnt; // 0..39
reg [7:0] chksum_calc, chksum_rx;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_WAIT_START; payload_cnt <= 0; chksum_calc <= 0; chksum_rx <= 0;
        plaintext <= 0; key192 <= 0; pkt_valid <= 0; pkt_error <= 0;
    end else begin
        pkt_valid <= 1'b0; pkt_error <= 1'b0;
        if (rx_valid) begin
            case (state)
                S_WAIT_START: if (rx_byte == 8'hAA) state <= S_CHECK_CMD;
                S_CHECK_CMD:  if (rx_byte == 8'h02) state <= S_RX_LEN_H; else begin state <= S_WAIT_START; pkt_error <= 1'b1; end
                S_RX_LEN_H:   if (rx_byte == 8'h00) state <= S_RX_LEN_L; else begin state <= S_WAIT_START; pkt_error <= 1'b1; end
                S_RX_LEN_L:   if (rx_byte == 8'h28) begin state <= S_RX_PAYLOAD; payload_cnt <= 0; chksum_calc <= 0; end else begin state <= S_WAIT_START; pkt_error <= 1'b1; end
                S_RX_PAYLOAD: begin
                    chksum_calc <= chksum_calc ^ rx_byte;
                    if (payload_cnt < 6'd16) plaintext <= {plaintext[119:0], rx_byte};
                    else key192 <= {key192[183:0], rx_byte};
                    if (payload_cnt == 6'd39) state <= S_RX_CHK;
                    else payload_cnt <= payload_cnt + 6'd1;
                end
                S_RX_CHK: begin chksum_rx <= rx_byte; state <= S_WAIT_END; end
                S_WAIT_END: begin
                    state <= S_WAIT_START;
                    if (rx_byte == 8'h55 && chksum_rx == chksum_calc) pkt_valid <= 1'b1;
                    else pkt_error <= 1'b1;
                end
                default: state <= S_WAIT_START;
            endcase
        end
    end
end

endmodule
