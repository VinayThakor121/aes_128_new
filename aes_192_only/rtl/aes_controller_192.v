`timescale 1ns / 1ps

module aes_controller_192 (
    input         clk,
    input         rst,
    input  [127:0] plaintext,
    input  [191:0] key192,
    input         pkt_valid,
    output reg [127:0] orig_pt,
    output reg [127:0] ct192,
    output reg [127:0] pt192,
    output reg         results_ready
);

reg [127:0] r_plaintext, din192;
reg [191:0] r_key192;
reg enc_dec, start192;
wire [127:0] out192;
wire done192;

mod_v2_top_192 u_aes192 (
    .clk(clk), .rst(rst), .key(r_key192), .data_in(din192),
    .enc_dec(enc_dec), .start(start192), .data_out(out192), .done(done192)
);

localparam [2:0] S_IDLE=3'd0, S_LATCH=3'd1, S_START_ENC=3'd2, S_WAIT_ENC=3'd3,
                 S_START_DEC=3'd4, S_WAIT_DEC=3'd5, S_DONE=3'd6;
reg [2:0] state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE; r_plaintext <= 0; r_key192 <= 0; din192 <= 0;
        enc_dec <= 1'b1; start192 <= 1'b0; orig_pt <= 0; ct192 <= 0; pt192 <= 0; results_ready <= 1'b0;
    end else begin
        start192 <= 1'b0;
        results_ready <= 1'b0;
        case (state)
            S_IDLE:  if (pkt_valid) state <= S_LATCH;
            S_LATCH: begin r_plaintext <= plaintext; r_key192 <= key192; orig_pt <= plaintext; state <= S_START_ENC; end
            S_START_ENC: begin din192 <= r_plaintext; enc_dec <= 1'b1; start192 <= 1'b1; state <= S_WAIT_ENC; end
            S_WAIT_ENC: if (done192) begin ct192 <= out192; state <= S_START_DEC; end
            S_START_DEC: begin din192 <= ct192; enc_dec <= 1'b0; start192 <= 1'b1; state <= S_WAIT_DEC; end
            S_WAIT_DEC: if (done192) begin pt192 <= out192; state <= S_DONE; end
            S_DONE: begin results_ready <= 1'b1; state <= S_IDLE; end
            default: state <= S_IDLE;
        endcase
    end
end

endmodule
