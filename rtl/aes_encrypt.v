// AES Parameterized Encryption
// FIPS-197 Section 5.1  (Cipher)
//
// Supports KEY_SIZE = 128, 192, or 256.
// Latency = Nr + 1 clock cycles after start pulse:
//   Cycle 1 : initial AddRoundKey
//   Cycles 2..(Nr) : full rounds (SubBytes, ShiftRows, MixColumns, AddRoundKey)
//   Cycle Nr+1 : final round (SubBytes, ShiftRows, AddRoundKey, no MixColumns)
//   done is asserted one cycle after the final round.
`timescale 1ns / 1ps

module aes_encrypt #(
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
// Round key access helper:
//   round_key(n) = round_keys_flat[ 1919 - 128*n  -: 128 ]
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
// State registers (declared before instantiations)
// ----------------------------------------------------------------
reg [127:0] state_reg;
reg [3:0]   round_cnt;   // current round number (1 .. Nr)

// ----------------------------------------------------------------
// Round transformation wires (combinatorial, driven from state_reg)
// ----------------------------------------------------------------
wire [127:0] sb_out, sr_out, mc_out;

aes_sub_bytes     u_sb  (.data_in(state_reg), .data_out(sb_out));
aes_shift_rows    u_sr  (.data_in(sb_out),    .data_out(sr_out));
aes_mix_columns   u_mc  (.data_in(sr_out),    .data_out(mc_out));

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
        ciphertext <= 128'd0;
    end else begin
        done <= 1'b0;
        case (fsm)
            S_IDLE: begin
                if (start) begin
                    // Initial AddRoundKey with round key 0
                    state_reg <= plaintext ^ get_rk(4'd0);
                    round_cnt <= 4'd1;
                    fsm       <= S_ROUND;
                end
            end

            S_ROUND: begin
                if (round_cnt == Nr[3:0]) begin
                    // Final round: SubBytes, ShiftRows, AddRoundKey (no MixColumns)
                    state_reg  <= sr_out ^ get_rk(round_cnt);
                    ciphertext <= sr_out ^ get_rk(round_cnt);
                    fsm        <= S_DONE;
                end else begin
                    // Full round: SubBytes, ShiftRows, MixColumns, AddRoundKey
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
