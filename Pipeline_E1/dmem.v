module dmem(
    input clk, we,
    input [31:0] a, wd,
    output [31:0] rd
);

  // 1024 palabras (4 KB): direcciones 0 a 4092. El programa del profesor
  // usa datos a partir de la direccion 1536
  reg [31:0] RAM[0:1023];
  integer i;

  initial begin
    for (i = 0; i < 1024; i = i + 1)
      RAM[i] = 0;
  end

  assign rd = RAM[a[11:2]];

  always @(posedge clk) begin
    if (we)
      RAM[a[11:2]] <= wd;
  end
endmodule
