`timescale 1ns / 1ps
//
// mod_v2_encrypt_256 — timing-optimised two-stage pipelined AES-256 encrypt
//
// Modified AES V2 (Abikoye et al.):
//   Only change from standard AES: SubBytes is replaced by ModSubBytes,
//   which XORs each state byte with a round-key-derived value before the S-box.
//
// Pipeline split
// --------------
//   Stage 1 (S_ROUND_S1): ModSubBytes → ShiftRows  → register sr_pipe / rk_pipe
//   Stage 2 (S_ROUND_S2): MixColumns(sr_pipe) ^ rk_pipe  → state_reg
//
// This limits each stage to ≈ 8.5 ns (well within 10 ns at 100 MHz).
//
// Key expansion
// -------------
// aes_key_expand_256_seq is instantiated here and produces all 15 round keys
// over 14 clock cycles after a key_load pulse.  key_load fires as a
// registered one-cycle pulse when start is asserted while the FSM is idle.
//
// Latency
// -------
//   14 (key expand) + 1 (initial ARK) + 14×2 (rounds 1-13, pipelined)
//   + 2 (final round: S_LAST_ARK) + 1 (S_DONE) = 46 cycles ≈ 460 ns at 100 MHz.
//
// Nr = 14 for AES-256.

module mod_v2_encrypt_256 (
    input              clk,
    input              rst,
    input  [127:0]     plaintext,
    input  [255:0]     key,
    input              start,
    output reg [127:0] ciphertext,
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
    S_LAST_ARK = 3'd4,
    S_DONE     = 3'd5;
reg [2:0] fsm;

// -----------------------------------------------------------------------
// Sequential key expansion
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
// Round key extraction from the flat bus
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
reg [127:0] sr_pipe;   // Stage-1 output: ShiftRows result
reg [127:0] rk_pipe;   // Stage-1 output: round key for Stage-2 ARK

// -----------------------------------------------------------------------
// Stage-1 combinatorial path  (ModSubBytes → ShiftRows)
// Critical path: rk mux (~2 ns) → xorkey (~1 ns) → S-box (~5.5 ns) ≈ 8.5 ns
// -----------------------------------------------------------------------
wire [127:0] rk_for_sb = get_rk(round_cnt);
wire [127:0] sb_out, sr_out;

mod_v2_sub_bytes u_sb (
    .data_in  (state_reg),
    .round_key(rk_for_sb),
    .data_out (sb_out)
);
aes_shift_rows u_sr (
    .data_in (sb_out),
    .data_out(sr_out)
);

// -----------------------------------------------------------------------
// Stage-2 combinatorial path  (MixColumns)
// Critical path: MixColumns (~3.5 ns) — comfortable
// -----------------------------------------------------------------------
wire [127:0] mc_out;
aes_mix_columns u_mc (
    .data_in (sr_pipe),
    .data_out(mc_out)
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
        ciphertext <= 128'd0;
        sr_pipe    <= 128'd0;
        rk_pipe    <= 128'd0;
        key_load_r <= 1'b0;
    end else begin
        done       <= 1'b0;
        key_load_r <= 1'b0;
        case (fsm)

            // Trigger key expansion and advance to wait state.
            S_IDLE: if (start) begin
                key_load_r <= 1'b1;
                fsm        <= S_KEY_WAIT;
            end

            // Wait for key expansion to complete (14 cycles).
            S_KEY_WAIT: if (rk_valid) begin
                state_reg <= plaintext ^ get_rk(4'd0);  // initial AddRoundKey
                round_cnt <= 4'd1;
                fsm       <= S_ROUND_S1;
            end

            // Stage 1: ModSubBytes(state_reg) → ShiftRows → sr_pipe
            //          Latch round key for Stage 2.
            S_ROUND_S1: begin
                sr_pipe <= sr_out;
                rk_pipe <= get_rk(round_cnt);
                fsm     <= (round_cnt == Nr[3:0]) ? S_LAST_ARK : S_ROUND_S2;
            end

            // Stage 2: MixColumns(sr_pipe) ^ rk_pipe → state_reg
            S_ROUND_S2: begin
                state_reg <= mc_out ^ rk_pipe;
                round_cnt <= round_cnt + 4'd1;
                fsm       <= S_ROUND_S1;
            end

            // Final round: AddRoundKey only (no MixColumns)
            S_LAST_ARK: begin
                ciphertext <= sr_pipe ^ rk_pipe;
                state_reg  <= sr_pipe ^ rk_pipe;
                fsm        <= S_DONE;
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
