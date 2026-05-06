// Modified AES V2 – Parameterized Decryption (Direct InvCipher)
// Paper: "Modified Advanced Encryption Standard Algorithm for Information Security"
//        (O.C. Abikoye et al.)
//
// Only change from standard AES: InvSubBytes is replaced by InvModSubBytes,
// which applies InvSBOX then XORs each byte with a round-key-derived value.
//
// KEY INSIGHT – which round key feeds InvModSubBytes:
//   Forward encryption round r uses ModSubBytes with rk[r].
//   The InvCipher processes decrypt rounds from Nr-1 down to 0.
//   At decrypt round_cnt = r, the step undoes the forward encryption round
//   that used rk[r+1]; therefore InvModSubBytes must receive rk[r+1].
//   AddRoundKey in the same step still uses rk[r] (unchanged).
//
// All other steps (InvShiftRows, InvMixColumns, AddRoundKey, key schedule) are
// identical to FIPS-197 and reuse the existing baseline modules.
//
// Supports KEY_SIZE = 128, 192, or 256.
// Latency = Nr + 1 clock cycles after start pulse (same as aes_decrypt).
`timescale 1ns / 1ps

module mod_v2_decrypt #(
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
// Key expansion (reused baseline module)
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
// State register
// ----------------------------------------------------------------
reg  [127:0] state_reg;
reg  [3:0]   round_cnt;

// ----------------------------------------------------------------
// Combinational round datapath
//
//   isr_out    = InvShiftRows(state_reg)               [standard baseline]
//   mod_isb    = InvModSubBytes(isr_out, rk[round_cnt+1])  [modified]
//   comb_ark   = mod_isb XOR rk[round_cnt]             [standard AddRoundKey]
//   imc_out    = InvMixColumns(comb_ark)               [standard baseline]
// ----------------------------------------------------------------
wire [127:0] isr_out;
wire [127:0] mod_isb_out;
wire [127:0] rk_for_isb;   // = rk[round_cnt + 1]
wire [127:0] comb_ark;
wire [127:0] imc_out;

aes_inv_shift_rows u_isr (
    .data_in  (state_reg),
    .data_out (isr_out)
);

// InvModSubBytes uses rk[round_cnt + 1] to undo the forward ModSubBytes
// that was applied with that round's key.
assign rk_for_isb = get_rk(round_cnt + 4'd1);

mod_v2_inv_sub_bytes u_misb (
    .data_in  (isr_out),
    .round_key(rk_for_isb),
    .data_out (mod_isb_out)
);

assign comb_ark = mod_isb_out ^ get_rk(round_cnt);

aes_inv_mix_columns u_imc (
    .data_in  (comb_ark),
    .data_out (imc_out)
);

// ----------------------------------------------------------------
// FSM  (identical structure to aes_decrypt)
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
                    // Initial AddRoundKey with round key Nr (unmodified)
                    state_reg <= ciphertext ^ get_rk(Nr[3:0]);
                    round_cnt <= Nr[3:0] - 4'd1;
                    fsm       <= S_ROUND;
                end
            end

            S_ROUND: begin
                if (round_cnt == 4'd0) begin
                    // Final inverse round: no InvMixColumns
                    plaintext <= comb_ark;
                    fsm       <= S_DONE;
                end else begin
                    // Full inverse round: apply InvMixColumns after AddRoundKey
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
