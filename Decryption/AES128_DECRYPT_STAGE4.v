`timescale 1ns / 1ps

module AES128_DECRYPT_STAGE4(
    input clk,
    input [127:0] IN_DATA,
    input [127:0] IN_KEY,
    output reg [127:0] OUT_DATA
);

// =====================================================
// Iterative AES-128 decrypt architecture
// =====================================================
// The previous implementation instantiated every key/decrypt round in
// parallel. This version reuses one round datapath across the AES rounds,
// which trades latency for much lower LUT utilization.

localparam [2:0] S_LOAD          = 3'd0,
                 S_WAIT_K0       = 3'd1,
                 S_EXPAND_KEY    = 3'd2,
                 S_DEC_LAST      = 3'd3,
                 S_DEC_ROUND     = 3'd4,
                 S_DONE          = 3'd5;

localparam [3:0] ROUND_WAIT = 4'd5;

reg [2:0] state = S_LOAD;
reg [3:0] wait_count = 4'd0;
reg [3:0] key_round = 4'd0;
reg [3:0] dec_round = 4'd0;

reg [127:0] cipher_reg = 128'd0;
reg [127:0] key_reg = 128'd0;
reg [127:0] decrypt_state = 128'd0;
reg [127:0] round_key [0:9];
reg [127:0] key_expand_in = 128'd0;

// K0 generation is performed once from the user key.
wire [127:0] perm_key;
wire [127:0] perm_key1;

SUB_BYTES s1(
    .clk(clk),
    .IN_DATA(key_reg),
    .SB_DATA(perm_key)
);

KEY_MODIFY_PART k1(
    .clk(clk),
    .IN_KEY(perm_key),
    .KEY_OUT(perm_key1)
);

// One shared forward round datapath for K1..K9 expansion.
wire [127:0] key_expand_out;
wire [127:0] unused_round_data;

ROUND_ITERATION key_round_unit(
    .clk(clk),
    .ROUND_KEY(key_round),
    .IN_DATA(128'd0),
    .IN_KEY(key_expand_in),
    .OUT_KEY(key_expand_out),
    .OUT_DATA(unused_round_data)
);

// One shared decrypt last-round datapath.
wire [127:0] inv_last_out;

INV_LAST_ROUND inv_last_unit(
    .clk(clk),
    .ROUND_KEY(4'd9),
    .IN_DATA(cipher_reg),
    .IN_KEY(round_key[9]),
    .OUT_DATA(inv_last_out)
);

// One shared inverse round datapath for rounds 8 down to 0.
wire [127:0] inv_round_out;

INV_ROUND_ITERATION_updated inv_round_unit(
    .clk(clk),
    .ROUND_KEY(dec_round),
    .IN_DATA(decrypt_state),
    .IN_KEY(round_key[dec_round]),
    .OUT_DATA(inv_round_out)
);

always @(posedge clk) begin
    case (state)
        S_LOAD: begin
            cipher_reg <= IN_DATA;
            key_reg <= IN_KEY;
            wait_count <= 4'd0;
            key_round <= 4'd0;
            dec_round <= 4'd8;
            state <= S_WAIT_K0;
        end

        S_WAIT_K0: begin
            if (wait_count == ROUND_WAIT) begin
                round_key[0] <= perm_key1;
                key_expand_in <= perm_key1;
                wait_count <= 4'd0;
                key_round <= 4'd0;
                state <= S_EXPAND_KEY;
            end else begin
                wait_count <= wait_count + 4'd1;
            end
        end

        S_EXPAND_KEY: begin
            if (wait_count == ROUND_WAIT) begin
                round_key[key_round + 4'd1] <= key_expand_out;
                key_expand_in <= key_expand_out;
                wait_count <= 4'd0;

                if (key_round == 4'd8) begin
                    state <= S_DEC_LAST;
                end else begin
                    key_round <= key_round + 4'd1;
                end
            end else begin
                wait_count <= wait_count + 4'd1;
            end
        end

        S_DEC_LAST: begin
            if (wait_count == ROUND_WAIT) begin
                decrypt_state <= inv_last_out;
                dec_round <= 4'd8;
                wait_count <= 4'd0;
                state <= S_DEC_ROUND;
            end else begin
                wait_count <= wait_count + 4'd1;
            end
        end

        S_DEC_ROUND: begin
            if (wait_count == ROUND_WAIT) begin
                wait_count <= 4'd0;

                if (dec_round == 4'd0) begin
                    OUT_DATA <= inv_round_out ^ round_key[0];
                    state <= S_DONE;
                end else begin
                    decrypt_state <= inv_round_out;
                    dec_round <= dec_round - 4'd1;
                end
            end else begin
                wait_count <= wait_count + 4'd1;
            end
        end

        S_DONE: begin
            if ((IN_DATA != cipher_reg) || (IN_KEY != key_reg)) begin
                state <= S_LOAD;
            end
        end

        default: begin
            state <= S_LOAD;
        end
    endcase
end

endmodule
