// UART Receiver — 16× oversampling
//
// Inputs:
//   clk, rst
//   baud_tick  — 1-cycle pulse at 16× the baud rate (from uart_baud_gen)
//   rx_serial  — raw serial input from FPGA pin
//
// Outputs:
//   rx_byte [7:0] — received byte (stable until next valid pulse)
//   rx_valid      — 1-cycle pulse when rx_byte holds a new byte
//
// Protocol: 1 start bit (low), 8 data bits LSB-first, 1 stop bit (high).
// No parity.  False-start detection: aborts if the start-bit sample at
// tick-8 is not still low.
`timescale 1ns / 1ps

module uart_rx (
    input        clk,
    input        rst,
    input        baud_tick,
    input        rx_serial,
    output reg [7:0] rx_byte,
    output reg       rx_valid
);

// Two-stage synchroniser to prevent metastability on the async serial input
reg rx_meta, rx_sync;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rx_meta <= 1'b1;
        rx_sync <= 1'b1;
    end else begin
        rx_meta <= rx_serial;
        rx_sync <= rx_meta;
    end
end

localparam [1:0] S_IDLE  = 2'd0,
                 S_START = 2'd1,
                 S_DATA  = 2'd2,
                 S_STOP  = 2'd3;

reg [1:0] state;
reg [3:0] tick_cnt;   // counts baud_ticks within a bit period (0-15)
reg [2:0] bit_cnt;    // counts received data bits (0-7)
reg [7:0] shift_reg;  // shift register, LSB first

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state     <= S_IDLE;
        tick_cnt  <= 4'd0;
        bit_cnt   <= 3'd0;
        shift_reg <= 8'd0;
        rx_byte   <= 8'd0;
        rx_valid  <= 1'b0;
    end else begin
        rx_valid <= 1'b0;   // default: de-asserted; set for one cycle below

        case (state)

            // Wait for the line to go low (start bit)
            S_IDLE: begin
                if (!rx_sync) begin
                    tick_cnt <= 4'd0;
                    state    <= S_START;
                end
            end

            // Count to the centre of the start bit (tick 7 = 8th tick)
            S_START: begin
                if (baud_tick) begin
                    if (tick_cnt == 4'd7) begin
                        if (!rx_sync) begin        // valid start bit
                            tick_cnt <= 4'd0;
                            bit_cnt  <= 3'd0;
                            state    <= S_DATA;
                        end else begin             // glitch — abort
                            state <= S_IDLE;
                        end
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            // Sample each data bit at its centre (every 16 ticks)
            S_DATA: begin
                if (baud_tick) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt  <= 4'd0;
                        // LSB first: push new bit into MSB, then shift right
                        shift_reg <= {rx_sync, shift_reg[7:1]};
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

            // Wait one full bit period for the stop bit then output
            S_STOP: begin
                if (baud_tick) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt <= 4'd0;
                        rx_byte  <= shift_reg;
                        rx_valid <= 1'b1;
                        state    <= S_IDLE;
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
