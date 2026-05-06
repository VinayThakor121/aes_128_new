module INV_MOD_ADDITION(
  input clk,
  input [127:0] IN_KEY,
  input [127:0] IN_DATA,   // MOD_ADD output
  output reg [127:0] OUT_DATA
);

integer i;
reg [8:0] temp;  // 9-bit to handle overflow safely

always @(*) begin
  for(i=0; i<16; i=i+1) begin
    // Perform safe subtraction with wrap-around
    temp = {1'b0, IN_DATA[8*i+:8]} + 9'd256 - {1'b0, IN_KEY[8*i+:8]};
    OUT_DATA[8*i+:8] = temp[7:0]; // take lower 8 bits (mod 256)
  end
end

endmodule