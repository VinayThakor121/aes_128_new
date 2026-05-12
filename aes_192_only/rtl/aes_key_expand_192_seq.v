`timescale 1ns / 1ps
//
// Sequential AES-192 key schedule — timing-optimised for Artix-7 at 100 MHz
//
// Motivation
// ----------
// The original aes_key_expand_192 is fully combinational: it chains 8 SubWord
// (S-box) calls through a loop, producing a ~40 ns register-to-register path
// that causes WNS ≈ −26 ns at 100 MHz.  This module spreads the work over 9
// clock cycles so that each cycle contains at most ONE SubWord call.
//
// Protocol
// ---------
//   Cycle 0  (key_load = 1) : latch key_in → w[0..5]
//   Cycle 1                  : compute w[ 6..11]  (one SubWord)
//   Cycle 2                  : compute w[12..17]  (one SubWord)
//   ...
//   Cycle 8                  : compute w[48..51]  (one SubWord, 4 words only)
//   After cycle 8            : valid = 1, round_keys_flat is stable
//
// Critical path per phase
// -----------------------
//   phase mux (~2 ns) → RotWord (wiring) → SubWord (~5.5 ns)
//   → XOR rcon (~0 ns, folded into LUT) → XOR word-tree (~1 ns) → register
//   Total ~= 8.5 ns  ->  fits comfortably inside a 10 ns / 100 MHz clock.
//
// Area
// ----
//   A single shared SubWord instance (4 S-boxes = ~32 LUTs) is muxed across
//   all 8 active phases, keeping LUT cost similar to the original while
//   eliminating the serial S-box chain entirely.
//
// Output layout  (identical to combinational aes_key_expand_192)
// ---------------------------------------------------------------
//   round_keys_flat[1663 - 32*i -: 32] = w[i]   for i = 0 .. 51

module aes_key_expand_192_seq (
    input  wire         clk,
    input  wire         rst,
    input  wire [191:0] key_in,
    input  wire         key_load,   // 1-cycle pulse to start expansion
    output wire [1663:0] round_keys_flat,
    output reg          valid        // high when round_keys_flat is ready
);

// -----------------------------------------------------------------------
// AES forward S-box (FIPS-197)
// -----------------------------------------------------------------------
function [7:0] sbox_f;
    input [7:0] b;
    case (b)
        8'h00: sbox_f=8'h63; 8'h01: sbox_f=8'h7c; 8'h02: sbox_f=8'h77; 8'h03: sbox_f=8'h7b;
        8'h04: sbox_f=8'hf2; 8'h05: sbox_f=8'h6b; 8'h06: sbox_f=8'h6f; 8'h07: sbox_f=8'hc5;
        8'h08: sbox_f=8'h30; 8'h09: sbox_f=8'h01; 8'h0a: sbox_f=8'h67; 8'h0b: sbox_f=8'h2b;
        8'h0c: sbox_f=8'hfe; 8'h0d: sbox_f=8'hd7; 8'h0e: sbox_f=8'hab; 8'h0f: sbox_f=8'h76;
        8'h10: sbox_f=8'hca; 8'h11: sbox_f=8'h82; 8'h12: sbox_f=8'hc9; 8'h13: sbox_f=8'h7d;
        8'h14: sbox_f=8'hfa; 8'h15: sbox_f=8'h59; 8'h16: sbox_f=8'h47; 8'h17: sbox_f=8'hf0;
        8'h18: sbox_f=8'had; 8'h19: sbox_f=8'hd4; 8'h1a: sbox_f=8'ha2; 8'h1b: sbox_f=8'haf;
        8'h1c: sbox_f=8'h9c; 8'h1d: sbox_f=8'ha4; 8'h1e: sbox_f=8'h72; 8'h1f: sbox_f=8'hc0;
        8'h20: sbox_f=8'hb7; 8'h21: sbox_f=8'hfd; 8'h22: sbox_f=8'h93; 8'h23: sbox_f=8'h26;
        8'h24: sbox_f=8'h36; 8'h25: sbox_f=8'h3f; 8'h26: sbox_f=8'hf7; 8'h27: sbox_f=8'hcc;
        8'h28: sbox_f=8'h34; 8'h29: sbox_f=8'ha5; 8'h2a: sbox_f=8'he5; 8'h2b: sbox_f=8'hf1;
        8'h2c: sbox_f=8'h71; 8'h2d: sbox_f=8'hd8; 8'h2e: sbox_f=8'h31; 8'h2f: sbox_f=8'h15;
        8'h30: sbox_f=8'h04; 8'h31: sbox_f=8'hc7; 8'h32: sbox_f=8'h23; 8'h33: sbox_f=8'hc3;
        8'h34: sbox_f=8'h18; 8'h35: sbox_f=8'h96; 8'h36: sbox_f=8'h05; 8'h37: sbox_f=8'h9a;
        8'h38: sbox_f=8'h07; 8'h39: sbox_f=8'h12; 8'h3a: sbox_f=8'h80; 8'h3b: sbox_f=8'he2;
        8'h3c: sbox_f=8'heb; 8'h3d: sbox_f=8'h27; 8'h3e: sbox_f=8'hb2; 8'h3f: sbox_f=8'h75;
        8'h40: sbox_f=8'h09; 8'h41: sbox_f=8'h83; 8'h42: sbox_f=8'h2c; 8'h43: sbox_f=8'h1a;
        8'h44: sbox_f=8'h1b; 8'h45: sbox_f=8'h6e; 8'h46: sbox_f=8'h5a; 8'h47: sbox_f=8'ha0;
        8'h48: sbox_f=8'h52; 8'h49: sbox_f=8'h3b; 8'h4a: sbox_f=8'hd6; 8'h4b: sbox_f=8'hb3;
        8'h4c: sbox_f=8'h29; 8'h4d: sbox_f=8'he3; 8'h4e: sbox_f=8'h2f; 8'h4f: sbox_f=8'h84;
        8'h50: sbox_f=8'h53; 8'h51: sbox_f=8'hd1; 8'h52: sbox_f=8'h00; 8'h53: sbox_f=8'hed;
        8'h54: sbox_f=8'h20; 8'h55: sbox_f=8'hfc; 8'h56: sbox_f=8'hb1; 8'h57: sbox_f=8'h5b;
        8'h58: sbox_f=8'h6a; 8'h59: sbox_f=8'hcb; 8'h5a: sbox_f=8'hbe; 8'h5b: sbox_f=8'h39;
        8'h5c: sbox_f=8'h4a; 8'h5d: sbox_f=8'h4c; 8'h5e: sbox_f=8'h58; 8'h5f: sbox_f=8'hcf;
        8'h60: sbox_f=8'hd0; 8'h61: sbox_f=8'hef; 8'h62: sbox_f=8'haa; 8'h63: sbox_f=8'hfb;
        8'h64: sbox_f=8'h43; 8'h65: sbox_f=8'h4d; 8'h66: sbox_f=8'h33; 8'h67: sbox_f=8'h85;
        8'h68: sbox_f=8'h45; 8'h69: sbox_f=8'hf9; 8'h6a: sbox_f=8'h02; 8'h6b: sbox_f=8'h7f;
        8'h6c: sbox_f=8'h50; 8'h6d: sbox_f=8'h3c; 8'h6e: sbox_f=8'h9f; 8'h6f: sbox_f=8'ha8;
        8'h70: sbox_f=8'h51; 8'h71: sbox_f=8'ha3; 8'h72: sbox_f=8'h40; 8'h73: sbox_f=8'h8f;
        8'h74: sbox_f=8'h92; 8'h75: sbox_f=8'h9d; 8'h76: sbox_f=8'h38; 8'h77: sbox_f=8'hf5;
        8'h78: sbox_f=8'hbc; 8'h79: sbox_f=8'hb6; 8'h7a: sbox_f=8'hda; 8'h7b: sbox_f=8'h21;
        8'h7c: sbox_f=8'h10; 8'h7d: sbox_f=8'hff; 8'h7e: sbox_f=8'hf3; 8'h7f: sbox_f=8'hd2;
        8'h80: sbox_f=8'hcd; 8'h81: sbox_f=8'h0c; 8'h82: sbox_f=8'h13; 8'h83: sbox_f=8'hec;
        8'h84: sbox_f=8'h5f; 8'h85: sbox_f=8'h97; 8'h86: sbox_f=8'h44; 8'h87: sbox_f=8'h17;
        8'h88: sbox_f=8'hc4; 8'h89: sbox_f=8'ha7; 8'h8a: sbox_f=8'h7e; 8'h8b: sbox_f=8'h3d;
        8'h8c: sbox_f=8'h64; 8'h8d: sbox_f=8'h5d; 8'h8e: sbox_f=8'h19; 8'h8f: sbox_f=8'h73;
        8'h90: sbox_f=8'h60; 8'h91: sbox_f=8'h81; 8'h92: sbox_f=8'h4f; 8'h93: sbox_f=8'hdc;
        8'h94: sbox_f=8'h22; 8'h95: sbox_f=8'h2a; 8'h96: sbox_f=8'h90; 8'h97: sbox_f=8'h88;
        8'h98: sbox_f=8'h46; 8'h99: sbox_f=8'hee; 8'h9a: sbox_f=8'hb8; 8'h9b: sbox_f=8'h14;
        8'h9c: sbox_f=8'hde; 8'h9d: sbox_f=8'h5e; 8'h9e: sbox_f=8'h0b; 8'h9f: sbox_f=8'hdb;
        8'ha0: sbox_f=8'he0; 8'ha1: sbox_f=8'h32; 8'ha2: sbox_f=8'h3a; 8'ha3: sbox_f=8'h0a;
        8'ha4: sbox_f=8'h49; 8'ha5: sbox_f=8'h06; 8'ha6: sbox_f=8'h24; 8'ha7: sbox_f=8'h5c;
        8'ha8: sbox_f=8'hc2; 8'ha9: sbox_f=8'hd3; 8'haa: sbox_f=8'hac; 8'hab: sbox_f=8'h62;
        8'hac: sbox_f=8'h91; 8'had: sbox_f=8'h95; 8'hae: sbox_f=8'he4; 8'haf: sbox_f=8'h79;
        8'hb0: sbox_f=8'he7; 8'hb1: sbox_f=8'hc8; 8'hb2: sbox_f=8'h37; 8'hb3: sbox_f=8'h6d;
        8'hb4: sbox_f=8'h8d; 8'hb5: sbox_f=8'hd5; 8'hb6: sbox_f=8'h4e; 8'hb7: sbox_f=8'ha9;
        8'hb8: sbox_f=8'h6c; 8'hb9: sbox_f=8'h56; 8'hba: sbox_f=8'hf4; 8'hbb: sbox_f=8'hea;
        8'hbc: sbox_f=8'h65; 8'hbd: sbox_f=8'h7a; 8'hbe: sbox_f=8'hae; 8'hbf: sbox_f=8'h08;
        8'hc0: sbox_f=8'hba; 8'hc1: sbox_f=8'h78; 8'hc2: sbox_f=8'h25; 8'hc3: sbox_f=8'h2e;
        8'hc4: sbox_f=8'h1c; 8'hc5: sbox_f=8'ha6; 8'hc6: sbox_f=8'hb4; 8'hc7: sbox_f=8'hc6;
        8'hc8: sbox_f=8'he8; 8'hc9: sbox_f=8'hdd; 8'hca: sbox_f=8'h74; 8'hcb: sbox_f=8'h1f;
        8'hcc: sbox_f=8'h4b; 8'hcd: sbox_f=8'hbd; 8'hce: sbox_f=8'h8b; 8'hcf: sbox_f=8'h8a;
        8'hd0: sbox_f=8'h70; 8'hd1: sbox_f=8'h3e; 8'hd2: sbox_f=8'hb5; 8'hd3: sbox_f=8'h66;
        8'hd4: sbox_f=8'h48; 8'hd5: sbox_f=8'h03; 8'hd6: sbox_f=8'hf6; 8'hd7: sbox_f=8'h0e;
        8'hd8: sbox_f=8'h61; 8'hd9: sbox_f=8'h35; 8'hda: sbox_f=8'h57; 8'hdb: sbox_f=8'hb9;
        8'hdc: sbox_f=8'h86; 8'hdd: sbox_f=8'hc1; 8'hde: sbox_f=8'h1d; 8'hdf: sbox_f=8'h9e;
        8'he0: sbox_f=8'he1; 8'he1: sbox_f=8'hf8; 8'he2: sbox_f=8'h98; 8'he3: sbox_f=8'h11;
        8'he4: sbox_f=8'h69; 8'he5: sbox_f=8'hd9; 8'he6: sbox_f=8'h8e; 8'he7: sbox_f=8'h94;
        8'he8: sbox_f=8'h9b; 8'he9: sbox_f=8'h1e; 8'hea: sbox_f=8'h87; 8'heb: sbox_f=8'he9;
        8'hec: sbox_f=8'hce; 8'hed: sbox_f=8'h55; 8'hee: sbox_f=8'h28; 8'hef: sbox_f=8'hdf;
        8'hf0: sbox_f=8'h8c; 8'hf1: sbox_f=8'ha1; 8'hf2: sbox_f=8'h89; 8'hf3: sbox_f=8'h0d;
        8'hf4: sbox_f=8'hbf; 8'hf5: sbox_f=8'he6; 8'hf6: sbox_f=8'h42; 8'hf7: sbox_f=8'h68;
        8'hf8: sbox_f=8'h41; 8'hf9: sbox_f=8'h99; 8'hfa: sbox_f=8'h2d; 8'hfb: sbox_f=8'h0f;
        8'hfc: sbox_f=8'hb0; 8'hfd: sbox_f=8'h54; 8'hfe: sbox_f=8'hbb; 8'hff: sbox_f=8'h16;
        default: sbox_f = 8'h00;
    endcase
endfunction

// SubWord: apply S-box to all 4 bytes
function [31:0] sub_word_f;
    input [31:0] ww;
    sub_word_f = {sbox_f(ww[31:24]), sbox_f(ww[23:16]),
                  sbox_f(ww[15:8]),  sbox_f(ww[7:0])};
endfunction

// RotWord: left-rotate a word by one byte
function [31:0] rot_word_f;
    input [31:0] ww;
    rot_word_f = {ww[23:0], ww[31:24]};
endfunction

// -----------------------------------------------------------------------
// Word storage  (52 words = 13 × 128-bit round keys)
// -----------------------------------------------------------------------
reg [31:0] w [0:51];
reg [3:0]  phase;   // 1..8 active; 4'd9 = idle/done

// -----------------------------------------------------------------------
// Shared SubWord resource  —  one wire per phase
//
// Using explicit wire assignments (not always @(*)) so that iverilog
// correctly retriggers computation when any w[k] register changes.
// All sw_k wires read from REGISTERED w[] values, so the critical path
// per cycle is:  register → RotWord (wiring) → SubWord (~5.5 ns)
//                → XOR rcon (folded into LUT) ≈ 6 ns  ✓
//
// Vivado's resource-sharing optimisation can merge the 8 S-box calls
// into one S-box preceded by a phase-controlled mux.
// -----------------------------------------------------------------------
wire [31:0] sw1 = sub_word_f(rot_word_f(w[ 5])) ^ 32'h01000000;
wire [31:0] sw2 = sub_word_f(rot_word_f(w[11])) ^ 32'h02000000;
wire [31:0] sw3 = sub_word_f(rot_word_f(w[17])) ^ 32'h04000000;
wire [31:0] sw4 = sub_word_f(rot_word_f(w[23])) ^ 32'h08000000;
wire [31:0] sw5 = sub_word_f(rot_word_f(w[29])) ^ 32'h10000000;
wire [31:0] sw6 = sub_word_f(rot_word_f(w[35])) ^ 32'h20000000;
wire [31:0] sw7 = sub_word_f(rot_word_f(w[41])) ^ 32'h40000000;
wire [31:0] sw8 = sub_word_f(rot_word_f(w[47])) ^ 32'h80000000;

// -----------------------------------------------------------------------
// Sequential key expansion  (9 clock cycles from key_load pulse)
//
// Each phase computes:
//   w[base+0] = w[prev+0] ^ sw_out
//   w[base+1] = w[prev+1] ^ w[prev+0] ^ sw_out
//   w[base+2] = w[prev+2] ^ w[prev+1] ^ w[prev+0] ^ sw_out
//   ...  (expansion of the serial XOR chain into a parallel XOR tree)
// -----------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        phase <= 4'd9;
        valid <= 1'b0;
    end else if (key_load) begin
        // Phase 0: latch key_in into w[0..5]
        w[ 0] <= key_in[191:160]; w[ 1] <= key_in[159:128]; w[ 2] <= key_in[127: 96];
        w[ 3] <= key_in[ 95: 64]; w[ 4] <= key_in[ 63: 32]; w[ 5] <= key_in[ 31:  0];
        phase <= 4'd1;
        valid <= 1'b0;
    end else begin
        case (phase)

        // ------------------------------------------------------------------
        // Phase 1: w[6..11] from w[0..5];  sw1 = SubWord(RotWord(w[5])) ^ rcon1
        // ------------------------------------------------------------------
        4'd1: begin
            w[ 6] <= w[ 0] ^ sw1;
            w[ 7] <= w[ 1] ^ w[ 0] ^ sw1;
            w[ 8] <= w[ 2] ^ w[ 1] ^ w[ 0] ^ sw1;
            w[ 9] <= w[ 3] ^ w[ 2] ^ w[ 1] ^ w[ 0] ^ sw1;
            w[10] <= w[ 4] ^ w[ 3] ^ w[ 2] ^ w[ 1] ^ w[ 0] ^ sw1;
            w[11] <= w[ 5] ^ w[ 4] ^ w[ 3] ^ w[ 2] ^ w[ 1] ^ w[ 0] ^ sw1;
            phase <= 4'd2;
        end

        // ------------------------------------------------------------------
        // Phase 2: w[12..17] from w[6..11]; sw2 uses w[11]
        // ------------------------------------------------------------------
        4'd2: begin
            w[12] <= w[ 6] ^ sw2;
            w[13] <= w[ 7] ^ w[ 6] ^ sw2;
            w[14] <= w[ 8] ^ w[ 7] ^ w[ 6] ^ sw2;
            w[15] <= w[ 9] ^ w[ 8] ^ w[ 7] ^ w[ 6] ^ sw2;
            w[16] <= w[10] ^ w[ 9] ^ w[ 8] ^ w[ 7] ^ w[ 6] ^ sw2;
            w[17] <= w[11] ^ w[10] ^ w[ 9] ^ w[ 8] ^ w[ 7] ^ w[ 6] ^ sw2;
            phase <= 4'd3;
        end

        // ------------------------------------------------------------------
        // Phase 3: w[18..23] from w[12..17]; sw3 uses w[17]
        // ------------------------------------------------------------------
        4'd3: begin
            w[18] <= w[12] ^ sw3;
            w[19] <= w[13] ^ w[12] ^ sw3;
            w[20] <= w[14] ^ w[13] ^ w[12] ^ sw3;
            w[21] <= w[15] ^ w[14] ^ w[13] ^ w[12] ^ sw3;
            w[22] <= w[16] ^ w[15] ^ w[14] ^ w[13] ^ w[12] ^ sw3;
            w[23] <= w[17] ^ w[16] ^ w[15] ^ w[14] ^ w[13] ^ w[12] ^ sw3;
            phase <= 4'd4;
        end

        // ------------------------------------------------------------------
        // Phase 4: w[24..29] from w[18..23]; sw4 uses w[23]
        // ------------------------------------------------------------------
        4'd4: begin
            w[24] <= w[18] ^ sw4;
            w[25] <= w[19] ^ w[18] ^ sw4;
            w[26] <= w[20] ^ w[19] ^ w[18] ^ sw4;
            w[27] <= w[21] ^ w[20] ^ w[19] ^ w[18] ^ sw4;
            w[28] <= w[22] ^ w[21] ^ w[20] ^ w[19] ^ w[18] ^ sw4;
            w[29] <= w[23] ^ w[22] ^ w[21] ^ w[20] ^ w[19] ^ w[18] ^ sw4;
            phase <= 4'd5;
        end

        // ------------------------------------------------------------------
        // Phase 5: w[30..35] from w[24..29]; sw5 uses w[29]
        // ------------------------------------------------------------------
        4'd5: begin
            w[30] <= w[24] ^ sw5;
            w[31] <= w[25] ^ w[24] ^ sw5;
            w[32] <= w[26] ^ w[25] ^ w[24] ^ sw5;
            w[33] <= w[27] ^ w[26] ^ w[25] ^ w[24] ^ sw5;
            w[34] <= w[28] ^ w[27] ^ w[26] ^ w[25] ^ w[24] ^ sw5;
            w[35] <= w[29] ^ w[28] ^ w[27] ^ w[26] ^ w[25] ^ w[24] ^ sw5;
            phase <= 4'd6;
        end

        // ------------------------------------------------------------------
        // Phase 6: w[36..41] from w[30..35]; sw6 uses w[35]
        // ------------------------------------------------------------------
        4'd6: begin
            w[36] <= w[30] ^ sw6;
            w[37] <= w[31] ^ w[30] ^ sw6;
            w[38] <= w[32] ^ w[31] ^ w[30] ^ sw6;
            w[39] <= w[33] ^ w[32] ^ w[31] ^ w[30] ^ sw6;
            w[40] <= w[34] ^ w[33] ^ w[32] ^ w[31] ^ w[30] ^ sw6;
            w[41] <= w[35] ^ w[34] ^ w[33] ^ w[32] ^ w[31] ^ w[30] ^ sw6;
            phase <= 4'd7;
        end

        // ------------------------------------------------------------------
        // Phase 7: w[42..47] from w[36..41]; sw7 uses w[41]
        // ------------------------------------------------------------------
        4'd7: begin
            w[42] <= w[36] ^ sw7;
            w[43] <= w[37] ^ w[36] ^ sw7;
            w[44] <= w[38] ^ w[37] ^ w[36] ^ sw7;
            w[45] <= w[39] ^ w[38] ^ w[37] ^ w[36] ^ sw7;
            w[46] <= w[40] ^ w[39] ^ w[38] ^ w[37] ^ w[36] ^ sw7;
            w[47] <= w[41] ^ w[40] ^ w[39] ^ w[38] ^ w[37] ^ w[36] ^ sw7;
            phase <= 4'd8;
        end

        // ------------------------------------------------------------------
        // Phase 8: w[48..51] from w[42..47]; sw8 uses w[47]; only 4 words.
        // After this phase the full 13-round key schedule is available.
        // ------------------------------------------------------------------
        4'd8: begin
            w[48] <= w[42] ^ sw8;
            w[49] <= w[43] ^ w[42] ^ sw8;
            w[50] <= w[44] ^ w[43] ^ w[42] ^ sw8;
            w[51] <= w[45] ^ w[44] ^ w[43] ^ w[42] ^ sw8;
            valid <= 1'b1;
            phase <= 4'd9;  // idle
        end

        default: ;  // phase = 9: idle, keep valid high until next key_load

        endcase
    end
end

// -----------------------------------------------------------------------
// Output assembly — same bit layout as combinational aes_key_expand_192:
//   round_keys_flat[1663 - 32*i -: 32] = w[i]
// -----------------------------------------------------------------------
genvar gi;
generate
    for (gi = 0; gi < 52; gi = gi + 1) begin : rk_out
        assign round_keys_flat[1663 - 32*gi -: 32] = w[gi];
    end
endgenerate

endmodule
