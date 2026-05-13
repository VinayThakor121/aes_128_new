`timescale 1ns / 1ps
//
// mod_v2_decrypt_256 — timing-optimised two-stage pipelined AES-256 decrypt
//
// Modified AES V2 (Abikoye et al.) — Inverse:
//   InvSubBytes is replaced by InvModSubBytes:
//     Forward:  out = SBOX( in XOR XORkey[row] )
//     Inverse:  out = InvSBOX( in ) XOR XORkey[row]
//
//   KEY INSIGHT — which round key feeds InvModSubBytes:
//     Forward encryption round r uses ModSubBytes with rk[r].
//     The InvCipher processes decrypt rounds from Nr-1 down to 0.
//     At decrypt round_cnt = r, the step undoes the forward encryption round
//     that used rk[r+1]; therefore InvModSubBytes must receive rk[r+1].
//     AddRoundKey in the same step still uses rk[r] (unchanged).
//
// Pipeline split
// --------------
//   Stage 1 (S_ROUND_S1): InvShiftRows → InvModSubBytes(rk[cnt+1]) → ARK(rk[cnt])
//                          → register ark_pipe
//   Stage 2 (S_ROUND_S2): InvMixColumns(ark_pipe) → state_reg
//
// Nr = 14 for AES-256.

module mod_v2_decrypt_256 (
    input              clk,
    input              rst,
    input  [127:0]     ciphertext,
    input  [255:0]     key,
    input              start,
    output reg [127:0] plaintext,
    output reg         done
);

localparam Nr = 14;

// -----------------------------------------------------------------------
// FSM state encoding
// -----------------------------------------------------------------------
localparam [2:0]
    S_IDLE     = 3'd0,
    S_KEY_WAIT = 3'd1,
    S_ROUND_S1 = 3'd2,
    S_ROUND_S2 = 3'd3,
    S_LAST_PT  = 3'd4,
    S_DONE     = 3'd5;
reg [2:0] fsm;

// -----------------------------------------------------------------------
// Sequential key expansion (registered key_load -- race-free)
// -----------------------------------------------------------------------
wire [1919:0] round_keys_flat;
wire          rk_valid;
reg           key_load_r;

aes_key_expand_256_seq u_kexp (
    .clk            (clk),
    .rst            (rst),
    .key_in         (key),
    .key_load       (key_load_r),
    .round_keys_flat(round_keys_flat),
    .valid          (rk_valid)
);

// -----------------------------------------------------------------------
// Round key extraction
// -----------------------------------------------------------------------
function [127:0] get_rk;
    input [3:0] n;
    get_rk = round_keys_flat[1919 - 128*n -: 128];
endfunction

// -----------------------------------------------------------------------
// Datapath registers
// -----------------------------------------------------------------------
reg [127:0] state_reg;
reg [3:0]   round_cnt;
reg [127:0] ark_pipe;  // Stage-1 output: result of InvSubBytes + ARK

// -----------------------------------------------------------------------
// Stage-1 combinatorial path
//   InvShiftRows → InvModSubBytes(rk[cnt+1]) → XOR rk[cnt]
// -----------------------------------------------------------------------
wire [127:0] isr_out;
wire [127:0] rk_for_isb = get_rk(round_cnt + 4'd1);
wire [127:0] mod_isb_out;
wire [127:0] comb_ark;

aes_inv_shift_rows u_isr (
    .data_in (state_reg),
    .data_out(isr_out)
);
mod_v2_inv_sub_bytes u_misb (
    .data_in  (isr_out),
    .round_key(rk_for_isb),
    .data_out (mod_isb_out)
);
assign comb_ark = mod_isb_out ^ get_rk(round_cnt);

// -----------------------------------------------------------------------
// Stage-2 combinatorial path  (InvMixColumns)
// -----------------------------------------------------------------------
wire [127:0] imc_out;
aes_inv_mix_columns u_imc (
    .data_in (ark_pipe),
    .data_out(imc_out)
);

// -----------------------------------------------------------------------
// FSM
// -----------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        fsm        <= S_IDLE;
        done       <= 1'b0;
        round_cnt  <= 4'd0;
        state_reg  <= 128'd0;
        plaintext  <= 128'd0;
        ark_pipe   <= 128'd0;
        key_load_r <= 1'b0;
    end else begin
        done       <= 1'b0;
        key_load_r <= 1'b0;
        case (fsm)

            S_IDLE: if (start) begin
                key_load_r <= 1'b1;
                fsm        <= S_KEY_WAIT;
            end

            S_KEY_WAIT: if (rk_valid) begin
                state_reg <= ciphertext ^ get_rk(Nr[3:0]);  // initial ARK with rk[14]
                round_cnt <= Nr[3:0] - 4'd1;                // = 13
                fsm       <= S_ROUND_S1;
            end

            // Stage 1: InvShiftRows → InvModSubBytes(rk[cnt+1]) → XOR(rk[cnt]) → ark_pipe
            S_ROUND_S1: begin
                ark_pipe <= comb_ark;
                fsm      <= (round_cnt == 4'd0) ? S_LAST_PT : S_ROUND_S2;
            end

            // Stage 2: InvMixColumns(ark_pipe) → state_reg
            S_ROUND_S2: begin
                state_reg <= imc_out;
                round_cnt <= round_cnt - 4'd1;
                fsm       <= S_ROUND_S1;
            end

            // Final round done: output the plaintext
            S_LAST_PT: begin
                plaintext <= ark_pipe;
                fsm       <= S_DONE;
            end

            S_DONE: begin
                done <= 1'b1;
                fsm  <= S_IDLE;
            end

            default: fsm <= S_IDLE;
        endcase
    end
end

endmodule
