// ---------------------------------------------------------------------------
// Banco de registros: 4 puertos de lectura, 2 de escritura
// ---------------------------------------------------------------------------
module regfile4r2w(input         clk,
                   input  [4:0]  a1_0, a2_0, a1_1, a2_1,
                   output [31:0] rd1_0, rd2_0, rd1_1, rd2_1,
                   input         we0, we1,
                   input  [4:0]  wa0, wa1,
                   input  [31:0] wd0, wd1);
 
  reg [31:0] rf[31:0];
 
  // Si las dos escriben el mismo rd, gana I1 (es la más nueva en el
  // programa): la última asignación del bloque es la que queda.
  always @(posedge clk) begin
    if (we0) rf[wa0] <= wd0;
    if (we1) rf[wa1] <= wd1;
  end
 
  assign rd1_0 = (a1_0 != 0) ? rf[a1_0] : 32'b0;
  assign rd2_0 = (a2_0 != 0) ? rf[a2_0] : 32'b0;
  assign rd1_1 = (a1_1 != 0) ? rf[a1_1] : 32'b0;
  assign rd2_1 = (a2_1 != 0) ? rf[a2_1] : 32'b0;
endmodule
