// UART Transmitter
//
// Inputs:
//   clk, rst
//   baud_tick  — 1-cycle pulse at 16× the baud rate (from uart_baud_gen)
//   tx_byte    — byte to transmit
//   tx_valid   — assert for 1 cycle while tx_ready is high to start TX
//
// Outputs:
//   tx_serial  — serial output to FPGA pin (idle-high)
//   tx_ready   — high when the transmitter is idle and can accept a byte
//
// Protocol: 1 start bit (low), 8 data bits LSB-first, 1 stop bit (high).
// No parity.
`timescale 1ns / 1ps

module uart_tx (
    input        clk,
    input        rst,
    input        baud_tick,
    input  [7:0] tx_byte,
    input        tx_valid,
    output reg   tx_serial,
    output       tx_ready
);

localparam [1:0] S_IDLE  = 2'd0,
                 S_START = 2'd1,
                 S_DATA  = 2'd2,
                 S_STOP  = 2'd3;

reg [1:0] state;
reg [3:0] tick_cnt;   // baud_tick counter within each bit period
reg [2:0] bit_cnt;    // data bit index (0-7)
reg [7:0] shift_reg;  // data shift register

assign tx_ready = (state == S_IDLE);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state     <= S_IDLE;
        tx_serial <= 1'b1;
        tick_cnt  <= 4'd0;
        bit_cnt   <= 3'd0;
        shift_reg <= 8'd0;
    end else begin
        case (state)

            S_IDLE: begin
                tx_serial <= 1'b1;
                if (tx_valid) begin
                    shift_reg <= tx_byte;
                    tick_cnt  <= 4'd0;
                    state     <= S_START;
                end
            end

            // Output start bit (low) for 16 ticks
            S_START: begin
                tx_serial <= 1'b0;
                if (baud_tick) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt <= 4'd0;
                        bit_cnt  <= 3'd0;
                        state    <= S_DATA;
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            // Output 8 data bits, LSB first, 16 ticks each
            S_DATA: begin
                tx_serial <= shift_reg[0];
                if (baud_tick) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt  <= 4'd0;
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        if (bit_cnt == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            // Output stop bit (high) for 16 ticks then return to idle
            S_STOP: begin
                tx_serial <= 1'b1;
                if (baud_tick) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt <= 4'd0;
                        state    <= S_IDLE;
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            default: begin
                state     <= S_IDLE;
                tx_serial <= 1'b1;
            end
        endcase
    end
end

endmodule
