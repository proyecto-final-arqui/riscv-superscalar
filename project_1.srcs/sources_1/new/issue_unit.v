// ---------------------------------------------------------------------------
// Unidad de emisión: decide si I1 sale en el mismo ciclo que I0
// ---------------------------------------------------------------------------
module issue_unit(input  [31:0] Instr0, Instr1,
                  input         RegWrite0, PCSrc0,
                  input         Mem0, Mem1,
                  output        Issue1);

  wire [4:0] rd0   = Instr0[11:7];
  wire [4:0] rs1_1 = Instr1[19:15];
  wire [4:0] rs2_1 = Instr1[24:20];
 
  // RAW dentro del bundle: I1 lee un registro que I0 escribe en este ciclo.
  // (Conservador: no mira si I1 realmente usa rs2. Un falso positivo solo
  //  cuesta un ciclo, nunca da un resultado incorrecto.)
  wire RAW     = RegWrite0 & (rd0 != 5'd0) & ((rd0 == rs1_1) | (rd0 == rs2_1));
 
  // Conflicto estructural: dmem tiene un solo puerto
  wire MemConf = Mem0 & Mem1;
 
  // Si I0 salta, I1 no debió ejecutarse
  assign Issue1 = ~RAW & ~MemConf & ~PCSrc0;
endmodule
