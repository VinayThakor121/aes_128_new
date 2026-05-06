// Modified AES V2 – Parameterized Encryption
// Paper: "Modified Advanced Encryption Standard Algorithm for Information Security"
//        (O.C. Abikoye et al.)
//
// Only change from standard AES: SubBytes is replaced by ModSubBytes,
// which XORs each state byte with a round-key-derived value before the S-box.
//
// All other steps (ShiftRows, MixColumns, AddRoundKey, key schedule) are
// identical to FIPS-197 and reuse the existing baseline modules.
//
// Supports KEY_SIZE = 128, 192, or 256.
// Latency = Nr + 1 clock cycles after start pulse (same as aes_encrypt).
`timescale 1ns / 1ps

module mod_v2_encrypt #(
    parameter KEY_SIZE = 128   // 128, 192, or 256
) (
    input                 clk,
    input                 rst,
    input  [127:0]        plaintext,
    input  [KEY_SIZE-1:0] key,
    input                 start,
    output reg [127:0]    ciphertext,
    output reg            done
);

localparam Nr = (KEY_SIZE == 128) ? 10 : (KEY_SIZE == 192) ? 12 : 14;

// ----------------------------------------------------------------
// Key expansion (reused baseline module – no duplication)
// ----------------------------------------------------------------
wire [1919:0] round_keys_flat;

aes_key_expand #(.KEY_SIZE(KEY_SIZE)) u_key_expand (
    .key_in          (key),
    .round_keys_flat (round_keys_flat)
);

// Extract round key n (0-based) from flat vector
function [127:0] get_rk;
    input [3:0] n;
    get_rk = round_keys_flat[1919 - 128*n -: 128];
endfunction

// ----------------------------------------------------------------
// State register
// ----------------------------------------------------------------
reg [127:0] state_reg;
reg [3:0]   round_cnt;

// ----------------------------------------------------------------
// Combinational round datapath (driven from state_reg + round_cnt)
//
// Modified path:  mod_v2_sub_bytes(state_reg, rk[round_cnt])
//                 → ShiftRows  → MixColumns
//
// ShiftRows and MixColumns are unchanged from standard AES.
// ----------------------------------------------------------------
wire [127:0] rk_for_sb;
wire [127:0] sb_out, sr_out, mc_out;

// Feed the current round key into ModSubBytes combinationally.
// round_cnt is a register, get_rk is a function over combinatorial
// round_keys_flat, so this path has no latches.
assign rk_for_sb = get_rk(round_cnt);

mod_v2_sub_bytes u_sb (
    .data_in  (state_reg),
    .round_key(rk_for_sb),
    .data_out (sb_out)
);

// Reuse standard baseline modules for ShiftRows and MixColumns
aes_shift_rows  u_sr (.data_in(sb_out),  .data_out(sr_out));
aes_mix_columns u_mc (.data_in(sr_out),  .data_out(mc_out));

// ----------------------------------------------------------------
// FSM  (identical structure to aes_encrypt)
// ----------------------------------------------------------------
localparam [1:0] S_IDLE  = 2'd0,
                 S_ROUND = 2'd1,
                 S_DONE  = 2'd2;

reg [1:0] fsm;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        fsm        <= S_IDLE;
        done       <= 1'b0;
        round_cnt  <= 4'd0;
        state_reg  <= 128'd0;
        ciphertext <= 128'd0;
    end else begin
        done <= 1'b0;
        case (fsm)
            S_IDLE: begin
                if (start) begin
                    // Initial AddRoundKey with round key 0 (unmodified)
                    state_reg <= plaintext ^ get_rk(4'd0);
                    round_cnt <= 4'd1;
                    fsm       <= S_ROUND;
                end
            end

            S_ROUND: begin
                if (round_cnt == Nr[3:0]) begin
                    // Final round: ModSubBytes, ShiftRows, AddRoundKey (no MixColumns)
                    state_reg  <= sr_out ^ get_rk(round_cnt);
                    ciphertext <= sr_out ^ get_rk(round_cnt);
                    fsm        <= S_DONE;
                end else begin
                    // Full round: ModSubBytes, ShiftRows, MixColumns, AddRoundKey
                    state_reg <= mc_out ^ get_rk(round_cnt);
                    round_cnt <= round_cnt + 4'd1;
                end
            end

            S_DONE: begin
                done <= 1'b1;
                if (start) begin
                    state_reg <= plaintext ^ get_rk(4'd0);
                    round_cnt <= 4'd1;
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
