module dual_issue(
    input [31:0] InstrD_0, InstrD_1,
    input RegWriteD_0, BranchD_0, JumpD_0,
    input StallD, BlockIssue1D,
    output Issue1D
);

  wire [6:0] op1;
  wire [4:0] rd0, rs1_1, rs2_1;
  wire ALU1, UsesRs2_1, RAW;

  assign op1 = InstrD_1[6:0];
  assign rd0 = InstrD_0[11:7];
  assign rs1_1 = InstrD_1[19:15];
  assign rs2_1 = InstrD_1[24:20];

  // Por ahora I1 solo puede emitir operaciones ALU
  assign ALU1 = (op1 == 7'b0110011) || (op1 == 7'b0010011);
  assign UsesRs2_1 = (op1 == 7'b0110011);

  // RAW dentro del par: I1 lee el registro que escribe I0
  assign RAW = RegWriteD_0 && (rd0 != 0) &&
               ((rs1_1 == rd0) || (UsesRs2_1 && (rs2_1 == rd0)));

  // BlockIssue1D conserva I1 cuando el hazard detecta un dato pendiente
  assign Issue1D = ALU1 && !BranchD_0 && !JumpD_0 &&
                   !RAW && !BlockIssue1D && !StallD;
endmodule
