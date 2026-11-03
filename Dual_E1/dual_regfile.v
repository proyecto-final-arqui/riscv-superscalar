module dual_regfile(
    input clk,
    input we_0, we_1,
    input [4:0] a1_0, a2_0, a1_1, a2_1,
    input [4:0] a3_0, a3_1,
    input [31:0] wd_0, wd_1,
    output [31:0] rd1_0, rd2_0, rd1_1, rd2_1
);

  reg [31:0] rf[31:0];
  integer i;

  // Arranca con todos los registros en cero
  initial begin
    for (i = 0; i < 32; i = i + 1)
      rf[i] = 0;
  end

  // Escribe en el flanco de bajada: ID lee en el mismo ciclo el dato de WB.
  // Si las dos vias escriben el mismo registro gana la via 1, que es la
  // instruccion mas joven del par
  always @(negedge clk) begin
    if (we_0 && (a3_0 != 0) && !(we_1 && (a3_1 == a3_0)))
      rf[a3_0] <= wd_0;
    if (we_1 && (a3_1 != 0))
      rf[a3_1] <= wd_1;
  end

  // Cuatro lecturas: rs1 y rs2 de cada via
  assign rd1_0 = (a1_0 != 0) ? rf[a1_0] : 0;
  assign rd2_0 = (a2_0 != 0) ? rf[a2_0] : 0;
  assign rd1_1 = (a1_1 != 0) ? rf[a1_1] : 0;
  assign rd2_1 = (a2_1 != 0) ? rf[a2_1] : 0;
endmodule
