module dual_fetch #(parameter MEMFILE = "program1.mem") (
    input [31:0] a,
    output [31:0] rd_0, rd_1
);

  reg [31:0] RAM[0:127];
  wire [31:0] a_1;
  integer i;

  // Rellena con NOP y luego carga el programa
  initial begin
    for (i = 0; i < 128; i = i + 1)
      RAM[i] = 32'h00000013;
    $readmemh(MEMFILE, RAM);
  end

  // Dual Fetch: lee la instruccion de PC y la de PC+4
  assign a_1 = a + 4;

  // Fuera de la memoria se lee NOP
  assign rd_0 = (a[31:9] == 0) ? RAM[a[8:2]] : 32'h00000013;
  assign rd_1 = (a_1[31:9] == 0) ? RAM[a_1[8:2]] : 32'h00000013;
endmodule
