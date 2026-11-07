module dual_datapath(
    input clk, reset,
    input [1:0] ImmSrcD_0, ImmSrcD_1,
    input Issue1D,
    input ALUSrcE_0, ALUSrcE_1,
    input [2:0] ALUControlE_0, ALUControlE_1,
    output ZeroE_0, ZeroE_1,
    output [31:0] PCTargetE,
    input PCSrcE, BranchSelE,
    input [1:0] ResultSrcM_0, ResultSrcM_1,
    input MemSelM,
    input RegWriteW_0, RegWriteW_1,
    input [1:0] ResultSrcW_0, ResultSrcW_1,
    input StallF, StallD, FlushD, FlushE,
    input [2:0] ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1,
    output [31:0] InstrD_0, InstrD_1,
    output reg [4:0] Rs1E_0, Rs2E_0, Rs1E_1, Rs2E_1, RdE_0, RdE_1,
    output reg [4:0] RdM_0, RdW_0, RdM_1, RdW_1,
    output reg [31:0] PCF,
    input [31:0] InstrF_0, InstrF_1,
    output [31:0] DataAdrM, WriteDataM,
    input [31:0] ReadDataM
);

  wire [31:0] PCNextF, PCPlus4F, PCPlus8F;
  wire LoadPairD;
  reg [31:0] InstrDReg_0, InstrDReg_1, PCD;
  reg ValidD;
  wire [31:0] PCPlus4D_0, PCPlus4D_1;
  wire [31:0] RD1D_0, RD2D_0, ImmExtD_0;
  wire [31:0] RD1D_1, RD2D_1, ImmExtD_1;

  reg [31:0] RD1E_0, RD2E_0, PCE_0, ImmExtE_0, PCPlus4E_0;
  reg [31:0] RD1E_1, RD2E_1, PCE_1, ImmExtE_1, PCPlus4E_1;
  reg [31:0] SrcAE_0, WriteDataE_0, SrcAE_1, WriteDataE_1;
  wire [31:0] SrcBE_0, ALUResultE_0, ForwardM_0, ForwardM_1;
  wire [31:0] SrcBE_1, ALUResultE_1;

  reg [31:0] ALUResultM_0, WriteDataM_0, PCPlus4M_0;
  reg [31:0] ALUResultM_1, WriteDataM_1, PCPlus4M_1;

  reg [31:0] ALUResultW_0, ReadDataW_0, PCPlus4W_0;
  reg [31:0] ALUResultW_1, ReadDataW_1, PCPlus4W_1;
  reg [31:0] ResultW_0, ResultW_1;

  // Con un par valido, Fetch apunta a las instrucciones siguientes: PCF = PCD + 8
  assign PCPlus4F = PCF + 4;
  assign PCPlus8F = PCF + 8;

  // Carga dos instrucciones si ID esta vacio o si se emitio el par
  assign LoadPairD = !ValidD || Issue1D;
  assign PCNextF = PCSrcE ? PCTargetE :
                   LoadPairD ? PCPlus8F : PCPlus4F;

  // StallF conserva el PC durante Load-Use
  always @(posedge clk or posedge reset) begin
    if (reset)
      PCF <= 0;
    else if (!StallF)
      PCF <= PCNextF;
  end

  // FlushD tiene prioridad sobre StallD
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      InstrDReg_0 <= 0;
      InstrDReg_1 <= 0;
      PCD <= 0;
      ValidD <= 0;
    end else if (FlushD) begin
      InstrDReg_0 <= 0;
      InstrDReg_1 <= 0;
      PCD <= 0;
      ValidD <= 0;
    end else if (!StallD) begin
      ValidD <= 1;
      if (LoadPairD) begin
        InstrDReg_0 <= InstrF_0;
        InstrDReg_1 <= InstrF_1;
        PCD <= PCF;
      end else begin
        // Conserva I1 como primera instruccion y agrega la siguiente
        InstrDReg_0 <= InstrDReg_1;
        InstrDReg_1 <= InstrF_0;
        PCD <= PCD + 4;
      end
    end
  end

  assign InstrD_0 = InstrDReg_0;
  assign InstrD_1 = InstrDReg_1;
  assign PCPlus4D_0 = PCD + 4;
  assign PCPlus4D_1 = PCD + 8;

  // Dual Decode: cuatro lecturas y dos escrituras
  dual_regfile rf(
    .clk(clk),
    .we_0(RegWriteW_0), .we_1(RegWriteW_1),
    .a1_0(InstrD_0[19:15]), .a2_0(InstrD_0[24:20]),
    .a1_1(InstrD_1[19:15]), .a2_1(InstrD_1[24:20]),
    .a3_0(RdW_0), .a3_1(RdW_1),
    .wd_0(ResultW_0), .wd_1(ResultW_1),
    .rd1_0(RD1D_0), .rd2_0(RD2D_0),
    .rd1_1(RD1D_1), .rd2_1(RD2D_1)
  );

  extend ext_0(.instr(InstrD_0[31:7]), .immsrc(ImmSrcD_0), .immext(ImmExtD_0));
  extend ext_1(.instr(InstrD_1[31:7]), .immsrc(ImmSrcD_1), .immext(ImmExtD_1));

  // Fuentes no usadas se pasan como x0
  wire UsesRs1D_0 = (InstrD_0[6:0] != 7'b1101111);
  wire UsesRs2D_0 = (InstrD_0[6:0] == 7'b0110011) ||
                    (InstrD_0[6:0] == 7'b0100011) ||
                    (InstrD_0[6:0] == 7'b1100011);
  wire UsesRs1D_1 = (InstrD_1[6:0] != 7'b1101111);
  wire UsesRs2D_1 = (InstrD_1[6:0] == 7'b0110011) ||
                    (InstrD_1[6:0] == 7'b0100011) ||
                    (InstrD_1[6:0] == 7'b1100011);

  // FlushE inserta una burbuja
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RD1E_0 <= 0;
      RD2E_0 <= 0;
      PCE_0 <= 0;
      ImmExtE_0 <= 0;
      PCPlus4E_0 <= 0;
      Rs1E_0 <= 0;
      Rs2E_0 <= 0;
      RdE_0 <= 0;
    end else if (FlushE) begin
      RD1E_0 <= 0;
      RD2E_0 <= 0;
      PCE_0 <= 0;
      ImmExtE_0 <= 0;
      PCPlus4E_0 <= 0;
      Rs1E_0 <= 0;
      Rs2E_0 <= 0;
      RdE_0 <= 0;
    end else begin
      RD1E_0 <= RD1D_0;
      RD2E_0 <= RD2D_0;
      PCE_0 <= PCD;
      ImmExtE_0 <= ImmExtD_0;
      PCPlus4E_0 <= PCPlus4D_0;
      Rs1E_0 <= UsesRs1D_0 ? InstrD_0[19:15] : 5'd0;
      Rs2E_0 <= UsesRs2D_0 ? InstrD_0[24:20] : 5'd0;
      RdE_0 <= InstrD_0[11:7];
    end
  end

  // Si la via 1 no emite entra una burbuja
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RD1E_1 <= 0;
      RD2E_1 <= 0;
      PCE_1 <= 0;
      ImmExtE_1 <= 0;
      PCPlus4E_1 <= 0;
      Rs1E_1 <= 0;
      Rs2E_1 <= 0;
      RdE_1 <= 0;
    end else if (FlushE || !Issue1D) begin
      RD1E_1 <= 0;
      RD2E_1 <= 0;
      PCE_1 <= 0;
      ImmExtE_1 <= 0;
      PCPlus4E_1 <= 0;
      Rs1E_1 <= 0;
      Rs2E_1 <= 0;
      RdE_1 <= 0;
    end else begin
      RD1E_1 <= RD1D_1;
      RD2E_1 <= RD2D_1;
      PCE_1 <= PCD + 4;
      ImmExtE_1 <= ImmExtD_1;
      PCPlus4E_1 <= PCPlus4D_1;
      Rs1E_1 <= UsesRs1D_1 ? InstrD_1[19:15] : 5'd0;
      Rs2E_1 <= UsesRs2D_1 ? InstrD_1[24:20] : 5'd0;
      RdE_1 <= InstrD_1[11:7];
    end
  end

  // Para jal se reenvia la direccion de retorno en cualquiera de las vias
  assign ForwardM_0 = (ResultSrcM_0 == 2'b10) ? PCPlus4M_0 : ALUResultM_0;
  assign ForwardM_1 = (ResultSrcM_1 == 2'b10) ? PCPlus4M_1 : ALUResultM_1;

  // 000: registro, 001: WB0, 010: WB1, 011: MEM0, 100: MEM1
  always @* begin
    case (ForwardAE_0)
      3'b001: SrcAE_0 = ResultW_0;
      3'b010: SrcAE_0 = ResultW_1;
      3'b011: SrcAE_0 = ForwardM_0;
      3'b100: SrcAE_0 = ForwardM_1;
      default: SrcAE_0 = RD1E_0;
    endcase

    case (ForwardBE_0)
      3'b001: WriteDataE_0 = ResultW_0;
      3'b010: WriteDataE_0 = ResultW_1;
      3'b011: WriteDataE_0 = ForwardM_0;
      3'b100: WriteDataE_0 = ForwardM_1;
      default: WriteDataE_0 = RD2E_0;
    endcase

    case (ForwardAE_1)
      3'b001: SrcAE_1 = ResultW_0;
      3'b010: SrcAE_1 = ResultW_1;
      3'b011: SrcAE_1 = ForwardM_0;
      3'b100: SrcAE_1 = ForwardM_1;
      default: SrcAE_1 = RD1E_1;
    endcase

    case (ForwardBE_1)
      3'b001: WriteDataE_1 = ResultW_0;
      3'b010: WriteDataE_1 = ResultW_1;
      3'b011: WriteDataE_1 = ForwardM_0;
      3'b100: WriteDataE_1 = ForwardM_1;
      default: WriteDataE_1 = RD2E_1;
    endcase
  end


  // El inmediato se elige despues del forwarding
  assign SrcBE_0 = ALUSrcE_0 ? ImmExtE_0 : WriteDataE_0;

  alu alu_0(
    .a(SrcAE_0), .b(SrcBE_0),
    .alucontrol(ALUControlE_0),
    .result(ALUResultE_0), .zero(ZeroE_0)
  );

  // Unico recurso de resolucion de saltos: suma el PC y el inmediato
  // de la via que tiene el beq o jal
  assign PCTargetE = BranchSelE ? (PCE_1 + ImmExtE_1) : (PCE_0 + ImmExtE_0);

  assign SrcBE_1 = ALUSrcE_1 ? ImmExtE_1 : WriteDataE_1;

  alu alu_1(
    .a(SrcAE_1), .b(SrcBE_1),
    .alucontrol(ALUControlE_1),
    .result(ALUResultE_1), .zero(ZeroE_1)
  );

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      ALUResultM_0 <= 0;
      WriteDataM_0 <= 0;
      PCPlus4M_0 <= 0;
      RdM_0 <= 0;
      ALUResultM_1 <= 0;
      WriteDataM_1 <= 0;
      PCPlus4M_1 <= 0;
      RdM_1 <= 0;
    end else begin
      ALUResultM_0 <= ALUResultE_0;
      WriteDataM_0 <= WriteDataE_0;
      PCPlus4M_0 <= PCPlus4E_0;
      RdM_0 <= RdE_0;
      ALUResultM_1 <= ALUResultE_1;
      WriteDataM_1 <= WriteDataE_1;
      PCPlus4M_1 <= PCPlus4E_1;
      RdM_1 <= RdE_1;
    end
  end

  // Un solo puerto de datos: MemSelM indica que lo usa la via 1
  assign DataAdrM = MemSelM ? ALUResultM_1 : ALUResultM_0;
  assign WriteDataM = MemSelM ? WriteDataM_1 : WriteDataM_0;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      ALUResultW_0 <= 0;
      ReadDataW_0 <= 0;
      PCPlus4W_0 <= 0;
      RdW_0 <= 0;
      ALUResultW_1 <= 0;
      ReadDataW_1 <= 0;
      PCPlus4W_1 <= 0;
      RdW_1 <= 0;
    end else begin
      ALUResultW_0 <= ALUResultM_0;
      ReadDataW_0 <= ReadDataM;
      PCPlus4W_0 <= PCPlus4M_0;
      RdW_0 <= RdM_0;
      ALUResultW_1 <= ALUResultM_1;
      ReadDataW_1 <= ReadDataM;
      PCPlus4W_1 <= PCPlus4M_1;
      RdW_1 <= RdM_1;
    end
  end

  always @* begin
    case (ResultSrcW_0)
      2'b01: ResultW_0 = ReadDataW_0;
      2'b10: ResultW_0 = PCPlus4W_0;
      default: ResultW_0 = ALUResultW_0;
    endcase

    case (ResultSrcW_1)
      2'b01: ResultW_1 = ReadDataW_1;
      2'b10: ResultW_1 = PCPlus4W_1;
      default: ResultW_1 = ALUResultW_1;
    endcase
  end
endmodule
