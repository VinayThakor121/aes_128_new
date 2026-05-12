`timescale 1ns / 1ps

module mod_v2_encrypt_192 (
    input              clk,
    input              rst,
    input  [127:0]     plaintext,
    input  [191:0]     key,
    input              start,
    output reg [127:0] ciphertext,
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

reg [127:0] state_reg;
reg [3:0]   round_cnt;
wire [127:0] rk_for_sb;
wire [127:0] sb_out, sr_out, mc_out;

assign rk_for_sb = get_rk(round_cnt);

mod_v2_sub_bytes u_sb (
    .data_in(state_reg),
    .round_key(rk_for_sb),
    .data_out(sb_out)
);

aes_shift_rows  u_sr (.data_in(sb_out), .data_out(sr_out));
aes_mix_columns u_mc (.data_in(sr_out), .data_out(mc_out));

localparam [1:0] S_IDLE=2'd0, S_ROUND=2'd1, S_DONE=2'd2;
reg [1:0] fsm;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        fsm <= S_IDLE; done <= 1'b0; round_cnt <= 4'd0;
        state_reg <= 128'd0; ciphertext <= 128'd0;
    end else begin
        done <= 1'b0;
        case (fsm)
            S_IDLE: if (start) begin
                state_reg <= plaintext ^ get_rk(4'd0);
                round_cnt <= 4'd1;
                fsm <= S_ROUND;
            end
            S_ROUND: begin
                if (round_cnt == Nr[3:0]) begin
                    state_reg  <= sr_out ^ get_rk(round_cnt);
                    ciphertext <= sr_out ^ get_rk(round_cnt);
                    fsm <= S_DONE;
                end else begin
                    state_reg <= mc_out ^ get_rk(round_cnt);
                    round_cnt <= round_cnt + 4'd1;
                end
            end
            S_DONE: begin
                done <= 1'b1;
                if (start) begin
                    state_reg <= plaintext ^ get_rk(4'd0);
                    round_cnt <= 4'd1;
                    fsm <= S_ROUND;
                end else fsm <= S_IDLE;
            end
            default: fsm <= S_IDLE;
        endcase
    end
end

endmodule
