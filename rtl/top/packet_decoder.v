// Packet Decoder — 94-byte UART input packet parser
//
// Packet format:
//   Byte  0    : 0xAA  — START marker
//   Byte  1    : 0x01  — CMD (run all AES)
//   Byte  2    : 0x00  — PAYLOAD_LEN high byte
//   Byte  3    : 0x58  — PAYLOAD_LEN low byte (88 decimal)
//   Bytes  4-19 : plaintext[127:0]  (16 bytes, MSB first)
//   Bytes 20-35 : key128[127:0]     (16 bytes, MSB first)
//   Bytes 36-59 : key192[191:0]     (24 bytes, MSB first)
//   Bytes 60-91 : key256[255:0]     (32 bytes, MSB first)
//   Byte  92    : XOR checksum of bytes 4-91
//   Byte  93    : 0x55  — END marker
//
// On a valid packet:   pkt_valid pulses high for 1 cycle.
// On a framing error:  pkt_error pulses high for 1 cycle; FSM resyncs to
//                      WAIT_START automatically.
`timescale 1ns / 1ps

module packet_decoder (
    input        clk,
    input        rst,
    // From uart_rx
    input  [7:0] rx_byte,
    input        rx_valid,
    // Decoded fields (held stable after pkt_valid until next valid packet)
    output reg [127:0] plaintext,
    output reg [127:0] key128,
    output reg [191:0] key192,
    output reg [255:0] key256,
    // Status (1-cycle pulses)
    output reg         pkt_valid,
    output reg         pkt_error
);

localparam [2:0] S_WAIT_START  = 3'd0,
                 S_CHECK_CMD   = 3'd1,
                 S_RX_LEN_H    = 3'd2,
                 S_RX_LEN_L    = 3'd3,
                 S_RX_PAYLOAD  = 3'd4,
                 S_RX_CHKSUM   = 3'd5,
                 S_WAIT_END    = 3'd6;

reg [2:0] state;
reg [6:0] payload_cnt;     // 0..87
reg [7:0] chksum_calc;     // running XOR over payload bytes
reg [7:0] chksum_rx;       // checksum byte received from packet

// Payload byte index → destination register mapping:
//   0..15  → plaintext  (16 bytes)
//   16..31 → key128     (16 bytes)
//   32..55 → key192     (24 bytes)
//   56..87 → key256     (32 bytes)

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state       <= S_WAIT_START;
        payload_cnt <= 7'd0;
        chksum_calc <= 8'd0;
        chksum_rx   <= 8'd0;
        plaintext   <= 128'd0;
        key128      <= 128'd0;
        key192      <= 192'd0;
        key256      <= 256'd0;
        pkt_valid   <= 1'b0;
        pkt_error   <= 1'b0;
    end else begin
        pkt_valid <= 1'b0;
        pkt_error <= 1'b0;

        if (rx_valid) begin
            case (state)

                S_WAIT_START: begin
                    // Stay here until 0xAA is seen — automatic resync
                    if (rx_byte == 8'hAA)
                        state <= S_CHECK_CMD;
                end

                S_CHECK_CMD: begin
                    if (rx_byte == 8'h01)
                        state <= S_RX_LEN_H;
                    else begin
                        state     <= S_WAIT_START;
                        pkt_error <= 1'b1;
                    end
                end

                S_RX_LEN_H: begin
                    if (rx_byte == 8'h00)
                        state <= S_RX_LEN_L;
                    else begin
                        state     <= S_WAIT_START;
                        pkt_error <= 1'b1;
                    end
                end

                S_RX_LEN_L: begin
                    if (rx_byte == 8'h58) begin   // 88 decimal
                        state       <= S_RX_PAYLOAD;
                        payload_cnt <= 7'd0;
                        chksum_calc <= 8'd0;
                    end else begin
                        state     <= S_WAIT_START;
                        pkt_error <= 1'b1;
                    end
                end

                S_RX_PAYLOAD: begin
                    // Accumulate XOR checksum
                    chksum_calc <= chksum_calc ^ rx_byte;

                    // Shift byte into the correct destination register
                    // MSB-first: each new byte goes into the LSB position;
                    // the first byte received ends up at the MSB after all
                    // bytes for that field have been loaded.
                    if (payload_cnt < 7'd16) begin
                        plaintext <= {plaintext[119:0], rx_byte};
                    end else if (payload_cnt < 7'd32) begin
                        key128 <= {key128[119:0], rx_byte};
                    end else if (payload_cnt < 7'd56) begin
                        key192 <= {key192[183:0], rx_byte};
                    end else begin
                        key256 <= {key256[247:0], rx_byte};
                    end

                    if (payload_cnt == 7'd87)
                        state <= S_RX_CHKSUM;
                    else
                        payload_cnt <= payload_cnt + 7'd1;
                end

                S_RX_CHKSUM: begin
                    chksum_rx <= rx_byte;
                    state     <= S_WAIT_END;
                end

                S_WAIT_END: begin
                    state <= S_WAIT_START;
                    if (rx_byte == 8'h55) begin
                        if (chksum_rx == chksum_calc)
                            pkt_valid <= 1'b1;
                        else
                            pkt_error <= 1'b1;
                    end else begin
                        pkt_error <= 1'b1;
                    end
                end

                default: state <= S_WAIT_START;
            endcase
        end
    end
end

endmodule
