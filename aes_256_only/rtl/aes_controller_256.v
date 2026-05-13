`timescale 1ns / 1ps

module aes_controller_256 (
    input         clk,
    input         rst,
    input  [127:0] plaintext,
    input  [255:0] key256,
    input         pkt_valid,
    output reg [127:0] orig_pt,
    output reg [127:0] ct256,
    output reg [127:0] pt256,
    output reg         results_ready
);

reg [127:0] r_plaintext, din256;
reg [255:0] r_key256;
reg enc_dec, start256;
wire [127:0] out256;
wire done256;

mod_v2_top_256 u_aes256 (
    .clk(clk), .rst(rst), .key(r_key256), .data_in(din256),
    .enc_dec(enc_dec), .start(start256), .data_out(out256), .done(done256)
);

localparam [2:0] S_IDLE      = 3'd0,
                 S_LATCH     = 3'd1,
                 S_START_ENC = 3'd2,
                 S_WAIT_ENC  = 3'd3,
                 S_START_DEC = 3'd4,
                 S_WAIT_DEC  = 3'd5,
                 S_DONE      = 3'd6;
reg [2:0] state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE; r_plaintext <= 0; r_key256 <= 0; din256 <= 0;
        enc_dec <= 1'b1; start256 <= 1'b0;
        orig_pt <= 0; ct256 <= 0; pt256 <= 0; results_ready <= 1'b0;
    end else begin
        start256      <= 1'b0;
        results_ready <= 1'b0;
        case (state)
            S_IDLE:      if (pkt_valid) state <= S_LATCH;
            S_LATCH:     begin
                r_plaintext <= plaintext; r_key256 <= key256;
                orig_pt     <= plaintext;
                state       <= S_START_ENC;
            end
            S_START_ENC: begin din256 <= r_plaintext; enc_dec <= 1'b1; start256 <= 1'b1; state <= S_WAIT_ENC; end
            S_WAIT_ENC:  if (done256) begin ct256 <= out256; state <= S_START_DEC; end
            S_START_DEC: begin din256 <= ct256; enc_dec <= 1'b0; start256 <= 1'b1; state <= S_WAIT_DEC; end
            S_WAIT_DEC:  if (done256) begin pt256 <= out256; state <= S_DONE; end
            S_DONE:      begin results_ready <= 1'b1; state <= S_IDLE; end
            default:     state <= S_IDLE;
        endcase
    end
end

endmodule
