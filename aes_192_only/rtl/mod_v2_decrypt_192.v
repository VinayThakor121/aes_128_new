`timescale 1ns / 1ps

module mod_v2_decrypt_192 (
    input              clk,
    input              rst,
    input  [127:0]     ciphertext,
    input  [191:0]     key,
    input              start,
    output reg [127:0] plaintext,
    output reg         done
);

localparam Nr = 12;

wire [1663:0] round_keys_flat;
aes_key_expand_192 u_key_expand (
    .key_in(key),
    .round_keys_flat(round_keys_flat)
);

function [127:0] get_rk;
    input [3:0] n;
    get_rk = round_keys_flat[1663 - 128*n -: 128];
endfunction

reg  [127:0] state_reg;
reg  [3:0]   round_cnt;
wire [127:0] isr_out, mod_isb_out, rk_for_isb, comb_ark, imc_out;

aes_inv_shift_rows u_isr (.data_in(state_reg), .data_out(isr_out));
assign rk_for_isb = get_rk(round_cnt + 4'd1);
mod_v2_inv_sub_bytes u_misb (.data_in(isr_out), .round_key(rk_for_isb), .data_out(mod_isb_out));
assign comb_ark = mod_isb_out ^ get_rk(round_cnt);
aes_inv_mix_columns u_imc (.data_in(comb_ark), .data_out(imc_out));

localparam [1:0] S_IDLE=2'd0, S_ROUND=2'd1, S_DONE=2'd2;
reg [1:0] fsm;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        fsm <= S_IDLE; done <= 1'b0; round_cnt <= 4'd0;
        state_reg <= 128'd0; plaintext <= 128'd0;
    end else begin
        done <= 1'b0;
        case (fsm)
            S_IDLE: if (start) begin
                state_reg <= ciphertext ^ get_rk(Nr[3:0]);
                round_cnt <= Nr[3:0] - 4'd1;
                fsm <= S_ROUND;
            end
            S_ROUND: begin
                if (round_cnt == 4'd0) begin
                    plaintext <= comb_ark;
                    fsm <= S_DONE;
                end else begin
                    state_reg <= imc_out;
                    round_cnt <= round_cnt - 4'd1;
                end
            end
            S_DONE: begin
                done <= 1'b1;
                if (start) begin
                    state_reg <= ciphertext ^ get_rk(Nr[3:0]);
                    round_cnt <= Nr[3:0] - 4'd1;
                    fsm <= S_ROUND;
                end else fsm <= S_IDLE;
            end
            default: fsm <= S_IDLE;
        endcase
    end
end

endmodule
