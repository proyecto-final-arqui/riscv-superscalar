// ---------------------------------------------------------------------------
// Datapath de 2 vías
// ---------------------------------------------------------------------------
module datapath_dual(input         clk, reset,
                     // ---- vía 0 ----
                     input  [1:0]  ResultSrc0,
                     input         PCSrc0, ALUSrc0, RegWrite0,
                     input  [1:0]  ImmSrc0,
                     input  [2:0]  ALUControl0,
                     output        Zero0,
                     // ---- vía 1 ----
                     input  [1:0]  ResultSrc1,
                     input         PCSrc1, ALUSrc1, RegWrite1,
                     input  [1:0]  ImmSrc1,
                     input  [2:0]  ALUControl1,
                     output        Zero1,
                     // ---- control del bundle ----
                     input         Issue1, MemSel,
                     output [31:0] PC,
                     input  [31:0] Instr0, Instr1,
                     output [31:0] DataAdr, WriteData,
                     input  [31:0] ReadData);
 
  localparam WIDTH = 32;
 
  wire [31:0] PCNext, PCPlus4, PCPlus8, PCTarget0, PCTarget1;
  wire [31:0] PCSeq, PCLane1;
  wire [31:0] ImmExt0, ImmExt1;
  wire [31:0] SrcA0, SrcB0, WriteData0, ALUResult0, Result0;
  wire [31:0] SrcA1, SrcB1, WriteData1, ALUResult1, Result1;
 
  // ======================= FETCH: lógica del PC =============================
  flopr #(WIDTH) pcreg(.clk(clk), .reset(reset), .d(PCNext), .q(PC));
 
  adder pcadd4(.a(PC), .b(32'd4), .y(PCPlus4));     // dirección de I1
  adder pcadd8(.a(PC), .b(32'd8), .y(PCPlus8));     // siguiente bundle
 
  adder pcaddbranch0(.a(PC),      .b(ImmExt0), .y(PCTarget0)); // salto de I0
  adder pcaddbranch1(.a(PCPlus4), .b(ImmExt1), .y(PCTarget1)); // salto de I1
 
  // Prioridad: salto de I0 > salto de I1 > secuencial (+8 si salieron las 2,
  // +4 si solo salió I0)
  mux2 #(WIDTH) seqmux  (.d0(PCPlus4), .d1(PCPlus8),   .s(Issue1), .y(PCSeq));
  mux2 #(WIDTH) lane1mux(.d0(PCSeq),   .d1(PCTarget1), .s(PCSrc1), .y(PCLane1));
  mux2 #(WIDTH) pcmux   (.d0(PCLane1), .d1(PCTarget0), .s(PCSrc0), .y(PCNext));
 
  // ================= DECODE: banco de registros 4R/2W ========================
  regfile4r2w rf(
    .clk(clk),
    .a1_0(Instr0[19:15]), .a2_0(Instr0[24:20]),
    .a1_1(Instr1[19:15]), .a2_1(Instr1[24:20]),
    .rd1_0(SrcA0), .rd2_0(WriteData0),
    .rd1_1(SrcA1), .rd2_1(WriteData1),
    .we0(RegWrite0), .wa0(Instr0[11:7]), .wd0(Result0),
    .we1(RegWrite1), .wa1(Instr1[11:7]), .wd1(Result1)
  );
 
  extend ext0(.instr(Instr0[31:7]), .immsrc(ImmSrc0), .immext(ImmExt0));
  extend ext1(.instr(Instr1[31:7]), .immsrc(ImmSrc1), .immext(ImmExt1));
 
  // ======================= EXECUTE: 2 ALUs ==================================
  mux2 #(WIDTH) srcbmux0(.d0(WriteData0), .d1(ImmExt0), .s(ALUSrc0), .y(SrcB0));
  mux2 #(WIDTH) srcbmux1(.d0(WriteData1), .d1(ImmExt1), .s(ALUSrc1), .y(SrcB1));
 
  alu alu0(.a(SrcA0), .b(SrcB0), .alucontrol(ALUControl0),
           .result(ALUResult0), .zero(Zero0));
  alu alu1(.a(SrcA1), .b(SrcB1), .alucontrol(ALUControl1),
           .result(ALUResult1), .zero(Zero1));
 
  // ============ MEMORIA: un puerto, lo usa la vía que lo necesite ===========
  mux2 #(WIDTH) adrmux(.d0(ALUResult0), .d1(ALUResult1), .s(MemSel), .y(DataAdr));
  mux2 #(WIDTH) wdmux (.d0(WriteData0), .d1(WriteData1), .s(MemSel), .y(WriteData));
 
  // ======================= WRITEBACK ========================================
  // Ojo: el "PC+4" de I1 (para jal) es PC+8
  mux3 #(WIDTH) resultmux0(.d0(ALUResult0), .d1(ReadData), .d2(PCPlus4),
                           .s(ResultSrc0), .y(Result0));
  mux3 #(WIDTH) resultmux1(.d0(ALUResult1), .d1(ReadData), .d2(PCPlus8),
                           .s(ResultSrc1), .y(Result1));
endmodule
