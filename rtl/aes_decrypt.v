// AES Parameterized Decryption (Direct InvCipher)
// FIPS-197 Section 5.3  (InvCipher)
//
// Supports KEY_SIZE = 128, 192, or 256.
// Latency = Nr + 1 clock cycles after start pulse (same as encryption).
//   Cycle 1 : initial AddRoundKey with round key Nr
//   Cycles 2..(Nr) : InvShiftRows, InvSubBytes, AddRoundKey, InvMixColumns
//   Cycle Nr+1 : final round  (InvShiftRows, InvSubBytes, AddRoundKey, no InvMixColumns)
//   done is asserted one cycle after the final round.
`timescale 1ns / 1ps

module aes_decrypt #(
    parameter KEY_SIZE = 128   // 128, 192, or 256
) (
    input                 clk,
    input                 rst,
    input  [127:0]        ciphertext,
    input  [KEY_SIZE-1:0] key,
    input                 start,
    output reg [127:0]    plaintext,
    output reg            done
);

localparam Nr = (KEY_SIZE == 128) ? 10 : (KEY_SIZE == 192) ? 12 : 14;

// ----------------------------------------------------------------
// Round key access helper
// ----------------------------------------------------------------
wire [1919:0] round_keys_flat;

aes_key_expand #(.KEY_SIZE(KEY_SIZE)) u_key_expand (
    .key_in          (key),
    .round_keys_flat (round_keys_flat)
);

function [127:0] get_rk;
    input [3:0] n;
    get_rk = round_keys_flat[1919 - 128*n -: 128];
endfunction

// ----------------------------------------------------------------
// Combinatorial round datapath on state_reg:
//   isr_out = InvShiftRows(state_reg)
//   isb_out = InvSubBytes(isr_out)
//   ark_out = isb_out XOR rk[round_cnt]   (done in FSM)
//   imc_out = InvMixColumns(ark_out)       (driven from comb_ark)
// ----------------------------------------------------------------
reg  [127:0] state_reg;
reg  [3:0]   round_cnt;
wire [127:0] isr_out, isb_out;

aes_inv_shift_rows u_isr (.data_in(state_reg), .data_out(isr_out));
aes_inv_sub_bytes  u_isb (.data_in(isr_out),   .data_out(isb_out));

// Combinatorial AddRoundKey XOR (fed into InvMixColumns for full rounds)
wire [127:0] comb_ark = isb_out ^ get_rk(round_cnt);
wire [127:0] imc_out;
aes_inv_mix_columns u_imc (.data_in(comb_ark), .data_out(imc_out));

// ----------------------------------------------------------------
// FSM
// ----------------------------------------------------------------
localparam [1:0] S_IDLE  = 2'd0,
                 S_ROUND = 2'd1,
                 S_DONE  = 2'd2;

reg [1:0] fsm;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        fsm       <= S_IDLE;
        done      <= 1'b0;
        round_cnt <= 4'd0;
        state_reg <= 128'd0;
        plaintext <= 128'd0;
    end else begin
        done <= 1'b0;
        case (fsm)
            S_IDLE: begin
                if (start) begin
                    // Initial AddRoundKey with round key Nr
                    state_reg <= ciphertext ^ get_rk(Nr[3:0]);
                    round_cnt <= Nr[3:0] - 4'd1;
                    fsm       <= S_ROUND;
                end
            end

            S_ROUND: begin
                // Combinatorial: isb_out = InvSubBytes(InvShiftRows(state_reg))
                //                comb_ark = isb_out ^ rk[round_cnt]
                //                imc_out  = InvMixColumns(comb_ark)
                if (round_cnt == 4'd0) begin
                    // Final round: no InvMixColumns; comb_ark = plaintext
                    plaintext <= comb_ark;
                    fsm       <= S_DONE;
                end else begin
                    // Full round: apply InvMixColumns after AddRoundKey
                    state_reg <= imc_out;
                    round_cnt <= round_cnt - 4'd1;
                end
            end

            S_DONE: begin
                done <= 1'b1;
                if (start) begin
                    state_reg <= ciphertext ^ get_rk(Nr[3:0]);
                    round_cnt <= Nr[3:0] - 4'd1;
                    fsm       <= S_ROUND;
                end else begin
                    fsm <= S_IDLE;
                end
            end

            default: fsm <= S_IDLE;
        endcase
    end
end

endmodule
