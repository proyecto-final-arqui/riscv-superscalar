module datapath_pipeline(
    input clk, reset,
    // Control de ID
    input [1:0] ImmSrcD,
    // Control de EX
    input ALUSrcE,
    input [2:0] ALUControlE,
    output ZeroE,
    output [31:0] PCTargetE,
    input PCSrcE,
    // Control de MEM y WB
    input [1:0] ResultSrcM,
    input RegWriteW,
    input [1:0] ResultSrcW,
    // Hazard Unit
    input StallF, StallD, FlushD, FlushE,
    input [1:0] ForwardAE, ForwardBE,
    output [31:0] InstrD,
    output reg [4:0] Rs1E, Rs2E, RdE,
    output reg [4:0] RdM, RdW,
    // Memorias
    output reg [31:0] PCF,
    input [31:0] InstrF,
    output reg [31:0] ALUResultM, WriteDataM,
    input [31:0] ReadDataM
);

  wire [31:0] PCNextF, PCPlus4F;
  reg [31:0] InstrDReg, PCD, PCPlus4D;
  wire [31:0] RD1D, RD2D, ImmExtD;
  reg [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
  reg [31:0] SrcAE, WriteDataE;
  wire [31:0] SrcBE, ALUResultE, ForwardM;
  reg [31:0] PCPlus4M;
  reg [31:0] ALUResultW, ReadDataW, PCPlus4W;
  reg [31:0] ResultW;
  // Solo para depurar: instruccion que esta en cada etapa (0 = burbuja)
  reg [31:0] InstrE, InstrM, InstrW;

  // ============================ IF ============================
  assign PCPlus4F = PCF + 4;
  assign PCNextF = PCSrcE ? PCTargetE : PCPlus4F;

  // StallF conserva el PC durante Load-Use
  always @(posedge clk or posedge reset) begin
    if (reset)
      PCF <= 0;
    else if (!StallF)
      PCF <= PCNextF;
  end

  // ========================== IF/ID ===========================
  // FlushD tiene prioridad sobre StallD
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      InstrDReg <= 0;
      PCD <= 0;
      PCPlus4D <= 0;
    end else if (FlushD) begin
      InstrDReg <= 0;
      PCD <= 0;
      PCPlus4D <= 0;
    end else if (!StallD) begin
      InstrDReg <= InstrF;
      PCD <= PCF;
      PCPlus4D <= PCPlus4F;
    end
  end

  assign InstrD = InstrDReg;

  // ============================ ID ============================
  regfile rf(
    .clk(clk),
    .we3(RegWriteW),
    .a1(InstrD[19:15]), .a2(InstrD[24:20]), .a3(RdW),
    .wd3(ResultW),
    .rd1(RD1D), .rd2(RD2D)
  );

  extend ext(.instr(InstrD[31:7]), .immsrc(ImmSrcD), .immext(ImmExtD));

  // En tipo I y J esos campos son parte del inmediato: se pasan como x0
  // para que la Hazard Unit no reenvie datos a un operando que no se usa
  wire UsesRs1D = (InstrD[6:0] != 7'b1101111);
  wire UsesRs2D = (InstrD[6:0] == 7'b0110011) ||
                  (InstrD[6:0] == 7'b0100011) ||
                  (InstrD[6:0] == 7'b1100011);

  // ========================== ID/EX ===========================
  // FlushE inserta una burbuja
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RD1E <= 0;
      RD2E <= 0;
      PCE <= 0;
      ImmExtE <= 0;
      PCPlus4E <= 0;
      Rs1E <= 0;
      Rs2E <= 0;
      RdE <= 0;
      InstrE <= 0;
    end else if (FlushE) begin
      RD1E <= 0;
      RD2E <= 0;
      PCE <= 0;
      ImmExtE <= 0;
      PCPlus4E <= 0;
      Rs1E <= 0;
      Rs2E <= 0;
      RdE <= 0;
      InstrE <= 0;
    end else begin
      RD1E <= RD1D;
      RD2E <= RD2D;
      PCE <= PCD;
      ImmExtE <= ImmExtD;
      PCPlus4E <= PCPlus4D;
      Rs1E <= UsesRs1D ? InstrD[19:15] : 5'd0;
      Rs2E <= UsesRs2D ? InstrD[24:20] : 5'd0;
      RdE <= InstrD[11:7];
      InstrE <= InstrD;
    end
  end

  // ============================ EX ============================
  // JAL reenvia PC+4 desde MEM; el resto reenvia el resultado de la ALU
  assign ForwardM = (ResultSrcM == 2'b10) ? PCPlus4M : ALUResultM;

  // 00: registro, 01: WB, 10: MEM
  always @* begin
    case (ForwardAE)
      2'b01: SrcAE = ResultW;
      2'b10: SrcAE = ForwardM;
      default: SrcAE = RD1E;
    endcase

    case (ForwardBE)
      2'b01: WriteDataE = ResultW;
      2'b10: WriteDataE = ForwardM;
      default: WriteDataE = RD2E;
    endcase
  end

  // El inmediato se elige despues del forwarding
  assign SrcBE = ALUSrcE ? ImmExtE : WriteDataE;

  alu alu(
    .a(SrcAE), .b(SrcBE),
    .alucontrol(ALUControlE),
    .result(ALUResultE), .zero(ZeroE)
  );

  assign PCTargetE = PCE + ImmExtE;

  // ========================== EX/MEM ==========================
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      ALUResultM <= 0;
      WriteDataM <= 0;
      PCPlus4M <= 0;
      RdM <= 0;
      InstrM <= 0;
    end else begin
      ALUResultM <= ALUResultE;
      WriteDataM <= WriteDataE;
      PCPlus4M <= PCPlus4E;
      RdM <= RdE;
      InstrM <= InstrE;
    end
  end

  // ========================== MEM/WB ==========================
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      ALUResultW <= 0;
      ReadDataW <= 0;
      PCPlus4W <= 0;
      RdW <= 0;
      InstrW <= 0;
    end else begin
      ALUResultW <= ALUResultM;
      ReadDataW <= ReadDataM;
      PCPlus4W <= PCPlus4M;
      RdW <= RdM;
      InstrW <= InstrM;
    end
  end

  // ============================ WB ============================
  always @* begin
    case (ResultSrcW)
      2'b01: ResultW = ReadDataW;
      2'b10: ResultW = PCPlus4W;
      default: ResultW = ALUResultW;
    endcase
  end
endmodule