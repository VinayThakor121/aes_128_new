`timescale 1ns / 1ps

module AES128_ENCRYPT_ITERATIVE(
    input clk,
    input [127:0] IN_DATA,
    input [127:0] IN_KEY,
    output reg [127:0] OUT_DATA
);

localparam [3:0] FSM_IDLE          = 4'd0;
localparam [3:0] FSM_INIT_PREP     = 4'd1;
localparam [3:0] FSM_INIT_WAIT     = 4'd2;
localparam [3:0] FSM_INIT_LOAD     = 4'd3;
localparam [3:0] FSM_ROUND_PREP    = 4'd4;
localparam [3:0] FSM_ROUND_WAIT_A  = 4'd5;
localparam [3:0] FSM_ROUND_WAIT_B  = 4'd6;
localparam [3:0] FSM_ROUND_WAIT_C  = 4'd7;
localparam [3:0] FSM_ROUND_APPLY   = 4'd8;
localparam [3:0] FSM_DONE          = 4'd9;

localparam [1:0] ROUND_WAIT = 2'd2;

reg [3:0] fsm_state = FSM_IDLE;
reg [1:0] wait_count = 2'd0;
reg [3:0] key_round = 4'd0;

reg [127:0] round_state = 128'd0;
reg [127:0] round_key = 128'd0;

reg [127:0] in_data_latched = 128'd0;
reg [127:0] in_key_latched = 128'd0;
reg inputs_seen = 1'b0;

reg [127:0] state_sbox_in = 128'd0;
wire [127:0] state_sbox_out;

reg [127:0] init_key_sbox_in = 128'd0;
wire [127:0] init_key_sbox_out;

reg [127:0] keygen_in = 128'd0;
wire [127:0] keygen_out;

reg [127:0] sub_bytes_hold = 128'd0;
reg [127:0] round_key_stage0 = 128'd0;
reg [127:0] round_key_stage1 = 128'd0;
reg [127:0] round_key_stage2 = 128'd0;

reg [127:0] key0_modified;
reg [127:0] next_state_value;

SUB_BYTES_ITER state_sbox_inst(
    .clk(clk),
    .IN_DATA(state_sbox_in),
    .SB_DATA(state_sbox_out)
);

SUB_BYTES_ITER init_key_sbox_inst(
    .clk(clk),
    .IN_DATA(init_key_sbox_in),
    .SB_DATA(init_key_sbox_out)
);

GENERATE_KEY_ITER keygen_inst(
    .clk(clk),
    .ROUND_KEY(key_round),
    .IN_KEY(keygen_in),
    .OUT_KEY(keygen_out)
);

always @(posedge clk) begin
    case (fsm_state)
        FSM_IDLE: begin
            if (!inputs_seen || IN_DATA != in_data_latched || IN_KEY != in_key_latched) begin
                in_data_latched <= IN_DATA;
                in_key_latched <= IN_KEY;
                inputs_seen <= 1'b1;
                fsm_state <= FSM_INIT_PREP;
            end
        end

        FSM_INIT_PREP: begin
            init_key_sbox_in <= in_key_latched;
            wait_count <= ROUND_WAIT;
            fsm_state <= FSM_INIT_WAIT;
        end

        FSM_INIT_WAIT: begin
            if (wait_count != 0) begin
                wait_count <= wait_count - 1'b1;
            end else begin
                fsm_state <= FSM_INIT_LOAD;
            end
        end

        FSM_INIT_LOAD: begin
            key0_modified = key_modify_part(init_key_sbox_out);
            round_key <= key0_modified;
            round_state <= in_data_latched ^ key0_modified;
            key_round <= 4'd0;
            fsm_state <= FSM_ROUND_PREP;
        end

        FSM_ROUND_PREP: begin
            state_sbox_in <= round_state;
            keygen_in <= round_key;
            wait_count <= ROUND_WAIT;
            fsm_state <= FSM_ROUND_WAIT_A;
        end

        FSM_ROUND_WAIT_A: begin
            if (wait_count != 0) begin
                wait_count <= wait_count - 1'b1;
            end else begin
                sub_bytes_hold <= state_sbox_out;
                round_key_stage0 <= keygen_out;
                keygen_in <= keygen_out;
                wait_count <= ROUND_WAIT;
                fsm_state <= FSM_ROUND_WAIT_B;
            end
        end

        FSM_ROUND_WAIT_B: begin
            if (wait_count != 0) begin
                wait_count <= wait_count - 1'b1;
            end else begin
                round_key_stage1 <= keygen_out;
                keygen_in <= keygen_out;
                wait_count <= ROUND_WAIT;
                fsm_state <= FSM_ROUND_WAIT_C;
            end
        end

        FSM_ROUND_WAIT_C: begin
            if (wait_count != 0) begin
                wait_count <= wait_count - 1'b1;
            end else begin
                round_key_stage2 <= keygen_out;
                fsm_state <= FSM_ROUND_APPLY;
            end
        end

        FSM_ROUND_APPLY: begin
            if (key_round == 4'd9) begin
                next_state_value = shift_rows(add_bytes_mod(sub_bytes_hold, round_key_stage0)) ^ round_key_stage1;
                round_state <= next_state_value;
                round_key <= round_key_stage1;
                OUT_DATA <= next_state_value;
                fsm_state <= FSM_DONE;
            end else begin
                next_state_value = mix_columns(
                    add_bytes_mod(
                        shift_rows(sub_bytes_hold ^ round_key_stage0),
                        round_key_stage1
                    )
                ) ^ round_key_stage2;

                round_state <= next_state_value;
                round_key <= round_key_stage2;
                key_round <= key_round + 1'b1;
                fsm_state <= FSM_ROUND_PREP;
            end
        end

        FSM_DONE: begin
            if (IN_DATA != in_data_latched || IN_KEY != in_key_latched) begin
                in_data_latched <= IN_DATA;
                in_key_latched <= IN_KEY;
                fsm_state <= FSM_INIT_PREP;
            end
        end

        default: begin
            fsm_state <= FSM_IDLE;
        end
    endcase
end

function [127:0] add_bytes_mod;
    input [127:0] lhs;
    input [127:0] rhs;
    integer i;
    begin
        for (i = 0; i < 16; i = i + 1) begin
            add_bytes_mod[(8*i) +: 8] = lhs[(8*i) +: 8] + rhs[(8*i) +: 8];
        end
    end
endfunction

function [127:0] shift_rows;
    input [127:0] data_in;
    begin
        shift_rows[127:120] = data_in[127:120];
        shift_rows[119:112] = data_in[87:80];
        shift_rows[111:104] = data_in[47:40];
        shift_rows[103:96]  = data_in[7:0];

        shift_rows[95:88]   = data_in[95:88];
        shift_rows[87:80]   = data_in[55:48];
        shift_rows[79:72]   = data_in[15:8];
        shift_rows[71:64]   = data_in[103:96];

        shift_rows[63:56]   = data_in[63:56];
        shift_rows[55:48]   = data_in[23:16];
        shift_rows[47:40]   = data_in[111:104];
        shift_rows[39:32]   = data_in[71:64];

        shift_rows[31:24]   = data_in[31:24];
        shift_rows[23:16]   = data_in[119:112];
        shift_rows[15:8]    = data_in[79:72];
        shift_rows[7:0]     = data_in[39:32];
    end
endfunction

function [127:0] mix_columns;
    input [127:0] data_in;
    begin
        mix_columns[127:120] = mixcolumn_byte(data_in[127:120], data_in[119:112], data_in[111:104], data_in[103:96]);
        mix_columns[119:112] = mixcolumn_byte(data_in[119:112], data_in[111:104], data_in[103:96], data_in[127:120]);
        mix_columns[111:104] = mixcolumn_byte(data_in[111:104], data_in[103:96], data_in[127:120], data_in[119:112]);
        mix_columns[103:96]  = mixcolumn_byte(data_in[103:96], data_in[127:120], data_in[119:112], data_in[111:104]);

        mix_columns[95:88]   = mixcolumn_byte(data_in[95:88], data_in[87:80], data_in[79:72], data_in[71:64]);
        mix_columns[87:80]   = mixcolumn_byte(data_in[87:80], data_in[79:72], data_in[71:64], data_in[95:88]);
        mix_columns[79:72]   = mixcolumn_byte(data_in[79:72], data_in[71:64], data_in[95:88], data_in[87:80]);
        mix_columns[71:64]   = mixcolumn_byte(data_in[71:64], data_in[95:88], data_in[87:80], data_in[79:72]);

        mix_columns[63:56]   = mixcolumn_byte(data_in[63:56], data_in[55:48], data_in[47:40], data_in[39:32]);
        mix_columns[55:48]   = mixcolumn_byte(data_in[55:48], data_in[47:40], data_in[39:32], data_in[63:56]);
        mix_columns[47:40]   = mixcolumn_byte(data_in[47:40], data_in[39:32], data_in[63:56], data_in[55:48]);
        mix_columns[39:32]   = mixcolumn_byte(data_in[39:32], data_in[63:56], data_in[55:48], data_in[47:40]);

        mix_columns[31:24]   = mixcolumn_byte(data_in[31:24], data_in[23:16], data_in[15:8], data_in[7:0]);
        mix_columns[23:16]   = mixcolumn_byte(data_in[23:16], data_in[15:8], data_in[7:0], data_in[31:24]);
        mix_columns[15:8]    = mixcolumn_byte(data_in[15:8], data_in[7:0], data_in[31:24], data_in[23:16]);
        mix_columns[7:0]     = mixcolumn_byte(data_in[7:0], data_in[31:24], data_in[23:16], data_in[15:8]);
    end
endfunction

function [7:0] mixcolumn_byte;
    input [7:0] in1;
    input [7:0] in2;
    input [7:0] in3;
    input [7:0] in4;
    begin
        mixcolumn_byte[7] = in1[6] ^ in2[6] ^ in2[7] ^ in3[7] ^ in4[7];
        mixcolumn_byte[6] = in1[5] ^ in2[5] ^ in2[6] ^ in3[6] ^ in4[6];
        mixcolumn_byte[5] = in1[4] ^ in2[4] ^ in2[5] ^ in3[5] ^ in4[5];
        mixcolumn_byte[4] = in1[3] ^ in1[7] ^ in2[3] ^ in2[4] ^ in2[7] ^ in3[4] ^ in4[4];
        mixcolumn_byte[3] = in1[2] ^ in1[7] ^ in2[2] ^ in2[3] ^ in2[7] ^ in3[3] ^ in4[3];
        mixcolumn_byte[2] = in1[1] ^ in2[1] ^ in2[2] ^ in3[2] ^ in4[2];
        mixcolumn_byte[1] = in1[0] ^ in1[7] ^ in2[0] ^ in2[1] ^ in2[7] ^ in3[1] ^ in4[1];
        mixcolumn_byte[0] = in1[7] ^ in2[7] ^ in2[0] ^ in3[0] ^ in4[0];
    end
endfunction

function [127:0] key_modify_part;
    input [127:0] in_key_words;
    reg [31:0] w0_tmp;
    reg [31:0] w1_tmp;
    reg [31:0] w2_tmp;
    reg [31:0] w3_tmp;
    reg [31:0] w0;
    reg [31:0] w1;
    reg [31:0] w2;
    reg [31:0] w3;
    begin
        w0_tmp = in_key_words[127:96];
        w1_tmp = in_key_words[95:64];
        w2_tmp = in_key_words[63:32];
        w3_tmp = in_key_words[31:0];

        w0 = w0_tmp ^ rcon4((w0_tmp[31:24] + 8'd3) % 8'd32);
        w1 = w1_tmp ^ rcon4((w1_tmp[31:24] + 8'd5) % 8'd32);
        w2 = w2_tmp ^ rcon4((w2_tmp[31:24] + 8'd7) % 8'd32);
        w3 = w3_tmp ^ rcon4((w3_tmp[31:24] + 8'd9) % 8'd32);

        key_modify_part = {w0, w1, w2, w3};
    end
endfunction

function [31:0] rcon4;
    input [7:0] round_index;
    begin
        case (round_index[3:0])
            4'h0: rcon4 = 32'h01_00_00_00;
            4'h1: rcon4 = 32'h02_00_00_00;
            4'h2: rcon4 = 32'h04_00_00_00;
            4'h3: rcon4 = 32'h08_00_00_00;
            4'h4: rcon4 = 32'h10_00_00_00;
            4'h5: rcon4 = 32'h20_00_00_00;
            4'h6: rcon4 = 32'h40_00_00_00;
            4'h7: rcon4 = 32'h80_00_00_00;
            4'h8: rcon4 = 32'h1b_00_00_00;
            4'h9: rcon4 = 32'h36_00_00_00;
            default: rcon4 = 32'h00_00_00_00;
        endcase
    end
endfunction

endmodule

module SUB_BYTES_ITER(
    input clk,
    input [127:0] IN_DATA,
    output [127:0] SB_DATA
);

FORWARD_SUBSTITUTION_BOX INST0 (.clk(clk), .A(IN_DATA[127:120]), .C(SB_DATA[127:120]));
FORWARD_SUBSTITUTION_BOX INST1 (.clk(clk), .A(IN_DATA[119:112]), .C(SB_DATA[119:112]));
FORWARD_SUBSTITUTION_BOX INST2 (.clk(clk), .A(IN_DATA[111:104]), .C(SB_DATA[111:104]));
FORWARD_SUBSTITUTION_BOX INST3 (.clk(clk), .A(IN_DATA[103:96]),  .C(SB_DATA[103:96]));
FORWARD_SUBSTITUTION_BOX INST4 (.clk(clk), .A(IN_DATA[95:88]),   .C(SB_DATA[95:88]));
FORWARD_SUBSTITUTION_BOX INST5 (.clk(clk), .A(IN_DATA[87:80]),   .C(SB_DATA[87:80]));
FORWARD_SUBSTITUTION_BOX INST6 (.clk(clk), .A(IN_DATA[79:72]),   .C(SB_DATA[79:72]));
FORWARD_SUBSTITUTION_BOX INST7 (.clk(clk), .A(IN_DATA[71:64]),   .C(SB_DATA[71:64]));
FORWARD_SUBSTITUTION_BOX INST8 (.clk(clk), .A(IN_DATA[63:56]),   .C(SB_DATA[63:56]));
FORWARD_SUBSTITUTION_BOX INST9 (.clk(clk), .A(IN_DATA[55:48]),   .C(SB_DATA[55:48]));
FORWARD_SUBSTITUTION_BOX INST10(.clk(clk), .A(IN_DATA[47:40]),   .C(SB_DATA[47:40]));
FORWARD_SUBSTITUTION_BOX INST11(.clk(clk), .A(IN_DATA[39:32]),   .C(SB_DATA[39:32]));
FORWARD_SUBSTITUTION_BOX INST12(.clk(clk), .A(IN_DATA[31:24]),   .C(SB_DATA[31:24]));
FORWARD_SUBSTITUTION_BOX INST13(.clk(clk), .A(IN_DATA[23:16]),   .C(SB_DATA[23:16]));
FORWARD_SUBSTITUTION_BOX INST14(.clk(clk), .A(IN_DATA[15:8]),    .C(SB_DATA[15:8]));
FORWARD_SUBSTITUTION_BOX INST15(.clk(clk), .A(IN_DATA[7:0]),     .C(SB_DATA[7:0]));

endmodule

module GENERATE_KEY_ITER(
    input clk,
    input [3:0] ROUND_KEY,
    input [127:0] IN_KEY,
    output [127:0] OUT_KEY
);

wire [31:0] KEY0;
wire [31:0] KEY1;
wire [31:0] KEY2;
wire [31:0] KEY3;
wire [31:0] C;

assign KEY3 = IN_KEY[127:96];
assign KEY2 = IN_KEY[95:64];
assign KEY1 = IN_KEY[63:32];
assign KEY0 = IN_KEY[31:0];

assign OUT_KEY[127:96] = KEY3 ^ C ^ rcon_iter(ROUND_KEY);
assign OUT_KEY[95:64]  = KEY3 ^ C ^ rcon_iter(ROUND_KEY) ^ KEY2;
assign OUT_KEY[63:32]  = KEY3 ^ C ^ rcon_iter(ROUND_KEY) ^ KEY2 ^ KEY1;
assign OUT_KEY[31:0]   = KEY3 ^ C ^ rcon_iter(ROUND_KEY) ^ KEY2 ^ KEY1 ^ KEY0;

FORWARD_SUBSTITUTION_BOX INST0(.clk(clk), .A(KEY0[23:16]), .C(C[31:24]));
FORWARD_SUBSTITUTION_BOX INST1(.clk(clk), .A(KEY0[15:8]),  .C(C[23:16]));
FORWARD_SUBSTITUTION_BOX INST2(.clk(clk), .A(KEY0[7:0]),   .C(C[15:8]));
FORWARD_SUBSTITUTION_BOX INST3(.clk(clk), .A(KEY0[31:24]), .C(C[7:0]));

function [31:0] rcon_iter;
    input [3:0] round_index;
    begin
        case (round_index)
            4'h0: rcon_iter = 32'h01_00_00_00;
            4'h1: rcon_iter = 32'h02_00_00_00;
            4'h2: rcon_iter = 32'h04_00_00_00;
            4'h3: rcon_iter = 32'h08_00_00_00;
            4'h4: rcon_iter = 32'h10_00_00_00;
            4'h5: rcon_iter = 32'h20_00_00_00;
            4'h6: rcon_iter = 32'h40_00_00_00;
            4'h7: rcon_iter = 32'h80_00_00_00;
            4'h8: rcon_iter = 32'h1b_00_00_00;
            4'h9: rcon_iter = 32'h36_00_00_00;
            default: rcon_iter = 32'h00_00_00_00;
        endcase
    end
endfunction

endmodule

module uart_rx #(parameter CLKS_PER_BIT = 868)(
    input clk,
    input rx,
    output reg [7:0] data_out = 0,
    output reg done = 0
);
    reg [3:0]  bit_index = 0;
    reg [13:0] clk_count = 0;
    reg [7:0]  rx_byte   = 0;
    reg        busy      = 0;

    always @(posedge clk) begin
        done <= 0;
        if (!busy && rx == 0) begin
            busy      <= 1;
            clk_count <= 0;
            bit_index <= 0;
        end
        else if (busy) begin
            if (clk_count == CLKS_PER_BIT/2 - 1) begin
                clk_count <= clk_count + 1;
                if (bit_index == 0 && rx != 0)
                    busy <= 0;
            end
            else if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 0;
                if (bit_index < 8) begin
                    rx_byte[bit_index] <= rx;
                    bit_index          <= bit_index + 1;
                end
                else begin
                    busy     <= 0;
                    data_out <= rx_byte;
                    done     <= 1;
                end
            end
            else begin
                clk_count <= clk_count + 1;
            end
        end
    end
endmodule

module uart_tx #(parameter CLKS_PER_BIT = 868)(
    input clk,
    input start,
    input [7:0] data_in,
    output reg tx   = 1,
    output reg busy = 0
);
    reg [3:0]  bit_index = 0;
    reg [13:0] clk_count = 0;
    reg [9:0]  tx_frame  = 10'h3FF;

    always @(posedge clk) begin
        if (start && !busy) begin
            busy      <= 1;
            bit_index <= 0;
            clk_count <= 0;
            tx_frame  <= {1'b1, data_in, 1'b0};
            tx        <= 0;
        end
        else if (busy) begin
            if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 0;
                bit_index <= bit_index + 1;
                if (bit_index < 9) begin
                    tx <= tx_frame[bit_index + 1];
                end
                else begin
                    tx   <= 1;
                    busy <= 0;
                end
            end
            else begin
                clk_count <= clk_count + 1;
            end
        end
    end
endmodule

module AES128_ENCRYPT_UART_WRAPPER #(
    parameter CLKS_PER_BIT = 868,
    parameter AES_WAIT_CYCLES = 140
)(
    input clk,
    input rx,
    output tx
);

localparam [2:0] WRAP_RX_COLLECT = 3'd0;
localparam [2:0] WRAP_AES_WAIT   = 3'd1;
localparam [2:0] WRAP_TX_LOAD    = 3'd2;
localparam [2:0] WRAP_TX_START   = 3'd3;
localparam [2:0] WRAP_TX_WAIT    = 3'd4;

reg [2:0] wrapper_state = WRAP_RX_COLLECT;

wire [7:0] rx_data;
wire rx_done;
reg [7:0] tx_data = 8'd0;
reg tx_start = 1'b0;
wire tx_busy;

reg [127:0] plaintext_shift = 128'd0;
reg [127:0] key_shift = 128'd0;
reg [127:0] cipher_shift = 128'd0;
reg [127:0] aes_in_data = 128'd0;
reg [127:0] aes_in_key = 128'd0;
wire [127:0] aes_out_data;

reg [5:0] rx_count = 6'd0;
reg [4:0] tx_count = 5'd0;
reg [15:0] aes_wait_count = 16'd0;

uart_rx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
) uart_rx_inst (
    .clk(clk),
    .rx(rx),
    .data_out(rx_data),
    .done(rx_done)
);

uart_tx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
) uart_tx_inst (
    .clk(clk),
    .start(tx_start),
    .data_in(tx_data),
    .tx(tx),
    .busy(tx_busy)
);

AES128_ENCRYPT_ITERATIVE aes_core (
    .clk(clk),
    .IN_DATA(aes_in_data),
    .IN_KEY(aes_in_key),
    .OUT_DATA(aes_out_data)
);

always @(posedge clk) begin
    tx_start <= 1'b0;

    case (wrapper_state)
        WRAP_RX_COLLECT: begin
            if (rx_done) begin
                if (rx_count < 6'd16) begin
                    plaintext_shift <= {plaintext_shift[119:0], rx_data};
                    rx_count <= rx_count + 1'b1;
                end
                else if (rx_count < 6'd31) begin
                    key_shift <= {key_shift[119:0], rx_data};
                    rx_count <= rx_count + 1'b1;
                end
                else begin
                    key_shift <= {key_shift[119:0], rx_data};
                    aes_in_data <= plaintext_shift;
                    aes_in_key <= {key_shift[119:0], rx_data};
                    rx_count <= 6'd0;
                    aes_wait_count <= 16'd0;
                    wrapper_state <= WRAP_AES_WAIT;
                end
            end
        end

        WRAP_AES_WAIT: begin
            if (aes_wait_count == AES_WAIT_CYCLES - 1) begin
                cipher_shift <= aes_out_data;
                tx_count <= 5'd0;
                wrapper_state <= WRAP_TX_LOAD;
            end
            else begin
                aes_wait_count <= aes_wait_count + 1'b1;
            end
        end

        WRAP_TX_LOAD: begin
            if (!tx_busy) begin
                tx_data <= cipher_shift[127:120];
                tx_start <= 1'b1;
                wrapper_state <= WRAP_TX_START;
            end
        end

        WRAP_TX_START: begin
            wrapper_state <= WRAP_TX_WAIT;
        end

        WRAP_TX_WAIT: begin
            if (!tx_busy) begin
                if (tx_count == 5'd15) begin
                    wrapper_state <= WRAP_RX_COLLECT;
                end
                else begin
                    cipher_shift <= {cipher_shift[119:0], 8'h00};
                    tx_count <= tx_count + 1'b1;
                    wrapper_state <= WRAP_TX_LOAD;
                end
            end
        end

        default: begin
            wrapper_state <= WRAP_RX_COLLECT;
        end
    endcase
end

endmodule
