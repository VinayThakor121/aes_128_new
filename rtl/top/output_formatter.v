// Output Formatter
//
// Serialises six 128-bit AES results into 6 × 18-byte binary frames and
// feeds them one byte at a time to uart_tx, honouring back-pressure via
// tx_ready.
//
// Frame format (18 bytes each):
//   Byte  0    : RESULT_ID (see table)
//   Bytes 1-16 : result data [127:0], MSB first
//   Byte  17   : XOR checksum of bytes 1-16
//
// RESULT_ID table:
//   0x11 → AES-128 ciphertext
//   0x12 → AES-192 ciphertext
//   0x13 → AES-256 ciphertext
//   0x21 → AES-128 decrypted plaintext
//   0x22 → AES-192 decrypted plaintext
//   0x23 → AES-256 decrypted plaintext
//
// results_ready (1-cycle pulse from aes_controller) starts transmission.
// tx_done pulses for 1 cycle after the last byte of the last frame is
// accepted by uart_tx.
`timescale 1ns / 1ps

module output_formatter (
    input        clk,
    input        rst,
    // Results from aes_controller
    input [127:0] ct128,
    input [127:0] ct192,
    input [127:0] ct256,
    input [127:0] pt128,
    input [127:0] pt192,
    input [127:0] pt256,
    input         results_ready,
    // To uart_tx
    output reg [7:0] tx_byte,
    output reg       tx_valid,
    input            tx_ready,
    // Done pulse
    output reg       tx_done
);

localparam [2:0] S_IDLE    = 3'd0,
                 S_TX_ID   = 3'd1,
                 S_TX_DATA = 3'd2,
                 S_TX_CHKS = 3'd3,
                 S_DONE    = 3'd4;

reg [2:0] state;
reg [2:0] result_idx;   // 0..5: which of the six results we are sending
reg [3:0] byte_cnt;     // 0..15: which data byte within a result
reg [7:0] chksum;       // running XOR checksum over the 16 data bytes
reg [127:0] tx_shift;   // 128-bit shift register, MSB first

// ---------------------------------------------------------------
// Look up the RESULT_ID for each index (combinational)
// ---------------------------------------------------------------
function [7:0] result_id_of;
    input [2:0] idx;
    begin
        case (idx)
            3'd0: result_id_of = 8'h11;
            3'd1: result_id_of = 8'h12;
            3'd2: result_id_of = 8'h13;
            3'd3: result_id_of = 8'h21;
            3'd4: result_id_of = 8'h22;
            3'd5: result_id_of = 8'h23;
            default: result_id_of = 8'h00;
        endcase
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state      <= S_IDLE;
        result_idx <= 3'd0;
        byte_cnt   <= 4'd0;
        chksum     <= 8'd0;
        tx_shift   <= 128'd0;
        tx_byte    <= 8'd0;
        tx_valid   <= 1'b0;
        tx_done    <= 1'b0;
    end else begin
        tx_valid <= 1'b0;   // default de-assert; overridden below for 1 cycle
        tx_done  <= 1'b0;

        case (state)

            S_IDLE: begin
                if (results_ready) begin
                    result_idx <= 3'd0;
                    state      <= S_TX_ID;
                end
            end

            // Send the RESULT_ID byte and load the data shift register
            S_TX_ID: begin
                if (tx_ready) begin
                    // Load the 128-bit shift register for this result
                    case (result_idx)
                        3'd0: tx_shift <= ct128;
                        3'd1: tx_shift <= ct192;
                        3'd2: tx_shift <= ct256;
                        3'd3: tx_shift <= pt128;
                        3'd4: tx_shift <= pt192;
                        3'd5: tx_shift <= pt256;
                        default: tx_shift <= 128'd0;
                    endcase
                    tx_byte  <= result_id_of(result_idx);
                    tx_valid <= 1'b1;
                    chksum   <= 8'd0;
                    byte_cnt <= 4'd0;
                    state    <= S_TX_DATA;
                end
            end

            // Send 16 data bytes, MSB first, accumulating checksum
            S_TX_DATA: begin
                if (tx_ready) begin
                    tx_byte  <= tx_shift[127:120];
                    tx_valid <= 1'b1;
                    chksum   <= chksum ^ tx_shift[127:120];
                    tx_shift <= {tx_shift[119:0], 8'd0};   // shift left
                    if (byte_cnt == 4'd15) begin
                        byte_cnt <= 4'd0;
                        state    <= S_TX_CHKS;
                    end else begin
                        byte_cnt <= byte_cnt + 4'd1;
                    end
                end
            end

            // Send the XOR checksum byte
            S_TX_CHKS: begin
                if (tx_ready) begin
                    tx_byte  <= chksum;
                    tx_valid <= 1'b1;
                    if (result_idx == 3'd5) begin
                        state <= S_DONE;
                    end else begin
                        result_idx <= result_idx + 3'd1;
                        state      <= S_TX_ID;
                    end
                end
            end

            S_DONE: begin
                tx_done <= 1'b1;
                state   <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
