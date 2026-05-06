// AES Controller
//
// Latches the decoded packet, schedules three parallel mod_v2_top cores
// (AES-128, AES-192, AES-256) for encryption then decryption, and asserts
// results_ready for one cycle when all six 128-bit results are valid.
//
// Execution sequence (FSM):
//   IDLE → LATCH_INPUTS → START_ENC → WAIT_ENC →
//   LATCH_CT → START_DEC → WAIT_DEC → LATCH_PT → SEND_RESULTS → IDLE
//
// All three encrypt cores are started in the same clock cycle; similarly
// for all three decrypt cores.  AES-256 is always the last to finish
// (Nr=14, 15 cycles), so done256 is used as the "all done" sentinel.
//
// The three mod_v2_top instances share enc_dec and individual start/data_in
// signals driven by this controller.
`timescale 1ns / 1ps

module aes_controller (
    input        clk,
    input        rst,
    // Decoded packet fields (stable while pkt_valid or shortly after)
    input [127:0] plaintext,
    input [127:0] key128,
    input [191:0] key192,
    input [255:0] key256,
    input         pkt_valid,
    // Results
    output reg [127:0] ct128,
    output reg [127:0] ct192,
    output reg [127:0] ct256,
    output reg [127:0] pt128,
    output reg [127:0] pt192,
    output reg [127:0] pt256,
    output reg         results_ready
);

// ---------------------------------------------------------------
// Registered inputs to the three AES cores
// ---------------------------------------------------------------
reg [127:0] r_plaintext;
reg [127:0] r_key128;
reg [191:0] r_key192;
reg [255:0] r_key256;

reg [127:0] din128, din192, din256;  // data_in per core
reg         enc_dec;                 // 1=encrypt, 0=decrypt (shared)
reg         start128, start192, start256;

// ---------------------------------------------------------------
// AES core outputs
// ---------------------------------------------------------------
wire [127:0] out128, out192, out256;
wire         done128, done192, done256;

mod_v2_top #(.KEY_SIZE(128)) u_aes128 (
    .clk     (clk),
    .rst     (rst),
    .key     (r_key128),
    .data_in (din128),
    .enc_dec (enc_dec),
    .start   (start128),
    .data_out(out128),
    .done    (done128)
);

mod_v2_top #(.KEY_SIZE(192)) u_aes192 (
    .clk     (clk),
    .rst     (rst),
    .key     (r_key192),
    .data_in (din192),
    .enc_dec (enc_dec),
    .start   (start192),
    .data_out(out192),
    .done    (done192)
);

mod_v2_top #(.KEY_SIZE(256)) u_aes256 (
    .clk     (clk),
    .rst     (rst),
    .key     (r_key256),
    .data_in (din256),
    .enc_dec (enc_dec),
    .start   (start256),
    .data_out(out256),
    .done    (done256)
);

// ---------------------------------------------------------------
// Controller FSM
// ---------------------------------------------------------------
localparam [3:0] S_IDLE         = 4'd0,
                 S_LATCH_INPUTS = 4'd1,
                 S_START_ENC    = 4'd2,
                 S_WAIT_ENC     = 4'd3,
                 S_LATCH_CT     = 4'd4,
                 S_START_DEC    = 4'd5,
                 S_WAIT_DEC     = 4'd6,
                 S_LATCH_PT     = 4'd7,
                 S_SEND_RESULTS = 4'd8;

reg [3:0] state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state         <= S_IDLE;
        r_plaintext   <= 128'd0;
        r_key128      <= 128'd0;
        r_key192      <= 192'd0;
        r_key256      <= 256'd0;
        din128        <= 128'd0;
        din192        <= 128'd0;
        din256        <= 128'd0;
        enc_dec       <= 1'b1;
        start128      <= 1'b0;
        start192      <= 1'b0;
        start256      <= 1'b0;
        ct128         <= 128'd0;
        ct192         <= 128'd0;
        ct256         <= 128'd0;
        pt128         <= 128'd0;
        pt192         <= 128'd0;
        pt256         <= 128'd0;
        results_ready <= 1'b0;
    end else begin
        // Default: de-assert one-cycle pulses
        start128      <= 1'b0;
        start192      <= 1'b0;
        start256      <= 1'b0;
        results_ready <= 1'b0;

        case (state)

            S_IDLE: begin
                if (pkt_valid)
                    state <= S_LATCH_INPUTS;
            end

            // Register packet fields so they stay stable during AES processing
            S_LATCH_INPUTS: begin
                r_plaintext <= plaintext;
                r_key128    <= key128;
                r_key192    <= key192;
                r_key256    <= key256;
                state       <= S_START_ENC;
            end

            // Launch all three encrypt cores simultaneously (1-cycle start pulse)
            S_START_ENC: begin
                din128  <= r_plaintext;
                din192  <= r_plaintext;
                din256  <= r_plaintext;
                enc_dec <= 1'b1;
                start128 <= 1'b1;
                start192 <= 1'b1;
                start256 <= 1'b1;
                state   <= S_WAIT_ENC;
            end

            // AES-256 (15 cycles) is always last; its done pulse signals all done
            S_WAIT_ENC: begin
                if (done256)
                    state <= S_LATCH_CT;
            end

            // Capture ciphertext outputs (AES-128/192 done regs still valid)
            S_LATCH_CT: begin
                ct128 <= out128;
                ct192 <= out192;
                ct256 <= out256;
                state <= S_START_DEC;
            end

            // Launch all three decrypt cores simultaneously using captured CTs
            S_START_DEC: begin
                din128  <= ct128;
                din192  <= ct192;
                din256  <= ct256;
                enc_dec <= 1'b0;
                start128 <= 1'b1;
                start192 <= 1'b1;
                start256 <= 1'b1;
                state   <= S_WAIT_DEC;
            end

            S_WAIT_DEC: begin
                if (done256)
                    state <= S_LATCH_PT;
            end

            S_LATCH_PT: begin
                pt128 <= out128;
                pt192 <= out192;
                pt256 <= out256;
                state <= S_SEND_RESULTS;
            end

            S_SEND_RESULTS: begin
                results_ready <= 1'b1;
                state         <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
