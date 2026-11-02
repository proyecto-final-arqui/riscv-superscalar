module regfile(
    input clk,
    input we3,
    input [4:0] a1, a2, a3,
    input [31:0] wd3,
    output [31:0] rd1, rd2
);

  reg [31:0] rf[31:0];
  integer i;

  // Arranca con todos los registros en cero
  initial begin
    for (i = 0; i < 32; i = i + 1)
      rf[i] = 0;
  end

  // Escribe en el flanco de bajada: ID lee en el mismo ciclo el dato de WB
  always @(negedge clk) begin
    if (we3 && (a3 != 0))
      rf[a3] <= wd3;
  end

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule
