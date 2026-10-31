// ---------------------------------------------------------------------------
// Procesador: 2 controllers (Dual Decode) + unidad de emisión + datapath
// ---------------------------------------------------------------------------
module riscvdual(input         clk, reset,
                 output [31:0] PC,
                 input  [31:0] Instr0, Instr1,
                 output        MemWrite,
                 output [31:0] DataAdr, WriteData,
                 input  [31:0] ReadData);
 
  // ---- señales de control de la vía 0 ----
  wire       ALUSrc0, RegWrite0, Jump0, Zero0, PCSrc0, MemWrite0;
  wire [1:0] ResultSrc0, ImmSrc0;
  wire [2:0] ALUControl0;
  // ---- señales de control de la vía 1 ----
  wire       ALUSrc1, RegWrite1, Jump1, Zero1, PCSrc1, MemWrite1;
  wire [1:0] ResultSrc1, ImmSrc1;
  wire [2:0] ALUControl1;
 
  wire Issue1;            // 1 = I1 se ejecuta en este ciclo
  wire Mem0, Mem1;        // la instrucción usa memoria de datos (lw/sw)
  wire MemSel;            // 0 = dmem la usa la vía 0, 1 = la usa la vía 1
 
  // ---------------- DUAL DECODE: tu controller, instanciado dos veces -------
  controller c0(
    .op(Instr0[6:0]), .funct3(Instr0[14:12]), .funct7b5(Instr0[30]),
    .Zero(Zero0),
    .ResultSrc(ResultSrc0), .MemWrite(MemWrite0),
    .PCSrc(PCSrc0), .ALUSrc(ALUSrc0),
    .RegWrite(RegWrite0), .Jump(Jump0),
    .ImmSrc(ImmSrc0), .ALUControl(ALUControl0)
  );
 
  controller c1(
    .op(Instr1[6:0]), .funct3(Instr1[14:12]), .funct7b5(Instr1[30]),
    .Zero(Zero1),
    .ResultSrc(ResultSrc1), .MemWrite(MemWrite1),
    .PCSrc(PCSrc1), .ALUSrc(ALUSrc1),
    .RegWrite(RegWrite1), .Jump(Jump1),
    .ImmSrc(ImmSrc1), .ALUControl(ALUControl1)
  );
 
  // ---------------- ¿Se pueden emitir las dos? ------------------------------
  assign Mem0 = MemWrite0 | (ResultSrc0 == 2'b01);   // sw o lw
  assign Mem1 = MemWrite1 | (ResultSrc1 == 2'b01);
 
  issue_unit iu(
    .Instr0(Instr0), .Instr1(Instr1),
    .RegWrite0(RegWrite0), .PCSrc0(PCSrc0),
    .Mem0(Mem0), .Mem1(Mem1),
    .Issue1(Issue1)
  );
 
  // Si I1 no se emite, se anulan sus efectos (escritura a registros y memoria)
  assign MemSel   = Issue1 & Mem1;
  assign MemWrite = MemSel ? (MemWrite1 & Issue1) : MemWrite0;
 
  datapath_dual dp(
    .clk(clk), .reset(reset),
    // vía 0
    .ResultSrc0(ResultSrc0), .PCSrc0(PCSrc0), .ALUSrc0(ALUSrc0),
    .RegWrite0(RegWrite0), .ImmSrc0(ImmSrc0), .ALUControl0(ALUControl0),
    .Zero0(Zero0),
    // vía 1 (gateada con Issue1)
    .ResultSrc1(ResultSrc1), .PCSrc1(PCSrc1 & Issue1), .ALUSrc1(ALUSrc1),
    .RegWrite1(RegWrite1 & Issue1), .ImmSrc1(ImmSrc1), .ALUControl1(ALUControl1),
    .Zero1(Zero1),
    // control del bundle
    .Issue1(Issue1), .MemSel(MemSel),
    .PC(PC), .Instr0(Instr0), .Instr1(Instr1),
    .DataAdr(DataAdr), .WriteData(WriteData), .ReadData(ReadData)
  );
endmodule
