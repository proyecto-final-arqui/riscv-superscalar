module imem #(parameter MEMFILE = "program1.mem") (
    input [31:0] a,
    output [31:0] rd
);

  reg [31:0] RAM[0:127];
  integer i;

  // Rellena con NOP y luego carga el programa
  initial begin
    for (i = 0; i < 128; i = i + 1)
      RAM[i] = 32'h00000013;
    $readmemh(MEMFILE, RAM);
  end

  // Fuera de la memoria se lee NOP
  assign rd = (a[31:9] == 0) ? RAM[a[8:2]] : 32'h00000013;
endmodule
