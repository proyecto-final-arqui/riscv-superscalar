module dual_issue(
    input [31:0] InstrD_0, InstrD_1,
    input RegWriteD_0, BranchD_0, JumpD_0,
    input StallD, BlockIssue1D,
    output Issue1D
);

  wire [6:0] op0, op1;
  wire [4:0] rd0, rs1_1, rs2_1;
  wire Valid1, Mem0, Mem1, Ctrl0, Ctrl1;
  wire UsesRs1_1, UsesRs2_1;
  wire RAW, MemConflict, BranchConflict;

  assign op0 = InstrD_0[6:0];
  assign op1 = InstrD_1[6:0];
  assign rd0 = InstrD_0[11:7];
  assign rs1_1 = InstrD_1[19:15];
  assign rs2_1 = InstrD_1[24:20];

  // I1 puede ser cualquier instruccion soportada: tipo R, tipo I, lw, sw, beq o jal
  assign Valid1 = (op1 == 7'b0110011) || (op1 == 7'b0010011) ||
                  (op1 == 7'b0000011) || (op1 == 7'b0100011) ||
                  (op1 == 7'b1100011) || (op1 == 7'b1101111);

  // Recursos compartidos: un puerto de memoria y una unidad de saltos
  assign Mem0 = (op0 == 7'b0000011) || (op0 == 7'b0100011);
  assign Mem1 = (op1 == 7'b0000011) || (op1 == 7'b0100011);
  assign Ctrl0 = BranchD_0 || JumpD_0;
  assign Ctrl1 = (op1 == 7'b1100011) || (op1 == 7'b1101111);

  // Si las dos usan el mismo recurso, I1 sale en el ciclo siguiente
  assign MemConflict = Mem0 && Mem1;
  assign BranchConflict = Ctrl0 && Ctrl1;

  // Registros que lee I1 (en jal esos campos son parte del inmediato)
  assign UsesRs1_1 = (op1 != 7'b1101111);
  assign UsesRs2_1 = (op1 == 7'b0110011) || (op1 == 7'b0100011) ||
                     (op1 == 7'b1100011);

  // RAW dentro del par: I1 lee el registro que escribe I0
  assign RAW = RegWriteD_0 && (rd0 != 0) &&
               ((UsesRs1_1 && (rs1_1 == rd0)) || (UsesRs2_1 && (rs2_1 == rd0)));

  // Si I0 es beq, I1 sale con ella y se anula en EX si el salto se toma.
  // Un jal siempre salta, asi que I1 seria anulada: se espera
  assign Issue1D = Valid1 && !JumpD_0 && !MemConflict && !BranchConflict &&
                   !RAW && !BlockIssue1D && !StallD;
endmodule
