module dmem(
    input clk, we,
    input [31:0] a, wd,
    output [31:0] rd
);

  reg [31:0] RAM[0:63];
  integer i;

  initial begin
    for (i = 0; i < 64; i = i + 1)
      RAM[i] = 0;
  end

  assign rd = RAM[a[7:2]];

  always @(posedge clk) begin
    if (we)
      RAM[a[7:2]] <= wd;
  end
endmodule
