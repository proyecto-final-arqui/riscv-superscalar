module dual_issue(
    input [31:0] InstrD_0, InstrD_1,
    input RegWriteD_0, BranchD_0, JumpD_0,
    input StallD,
    input RegWriteE_0,
    input [1:0] ResultSrcE_0,
    input [4:0] RdE_0,
    output Issue1D
);

  wire [6:0] op1;
  wire [4:0] rd0, rs1_1, rs2_1;
  wire ALU1, UsesRs2_1, RAW, LoadUse1;

  assign op1 = InstrD_1[6:0];
  assign rd0 = InstrD_0[11:7];
  assign rs1_1 = InstrD_1[19:15];
  assign rs2_1 = InstrD_1[24:20];

  // Por ahora la via 1 solo acepta operaciones ALU (tipo R y tipo I).
  // lw, sw, beq y jal siempre salen por la via 0
  assign ALU1 = (op1 == 7'b0110011) || (op1 == 7'b0010011);
  assign UsesRs2_1 = (op1 == 7'b0110011);

  // RAW dentro del par: I1 lee el registro que escribe I0
  assign RAW = RegWriteD_0 && (rd0 != 0) &&
               ((rs1_1 == rd0) || (UsesRs2_1 && (rs2_1 == rd0)));

  // I1 necesita el dato de una carga que esta en EX: todavia no hay dato
  assign LoadUse1 = RegWriteE_0 && (ResultSrcE_0 == 2'b01) && (RdE_0 != 0) &&
                    ((rs1_1 == RdE_0) || (UsesRs2_1 && (rs2_1 == RdE_0)));

  // Si I0 es un salto, I1 puede ser del camino equivocado: espera.
  // Si I0 esta en pausa, I1 tampoco sale para no adelantarse
  assign Issue1D = ALU1 && !BranchD_0 && !JumpD_0 &&
                   !RAW && !LoadUse1 && !StallD;
endmodule
