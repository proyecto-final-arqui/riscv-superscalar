module dual_decode(
    input clk, reset,
    input [31:0] InstrD_0, InstrD_1,
    input ZeroE_0, ZeroE_1,
    input [4:0] Rs1E_0, Rs2E_0, Rs1E_1, Rs2E_1,
    input [4:0] RdE_0, RdE_1, RdM_0, RdW_0, RdM_1, RdW_1,
    output Issue1D,
    output [2:0] ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1,
    output StallF, StallD,
    output FlushD, FlushE,
    output [1:0] ImmSrcD_0, ImmSrcD_1,
    output reg ALUSrcE_0, ALUSrcE_1,
    output reg [2:0] ALUControlE_0, ALUControlE_1,
    output PCSrcE, BranchSelE,
    output MemWriteM, MemSelM,
    output reg [1:0] ResultSrcM_0, ResultSrcM_1,
    output reg RegWriteW_0, RegWriteW_1,
    output reg [1:0] ResultSrcW_0, ResultSrcW_1
);

  wire RegWriteD_0, MemWriteD_0, BranchD_0, ALUSrcD_0, JumpD_0;
  wire RegWriteD_1, MemWriteD_1, BranchD_1, ALUSrcD_1, JumpD_1;
  wire [1:0] ResultSrcD_0, ALUOpD_0, ResultSrcD_1, ALUOpD_1;
  wire [2:0] ALUControlD_0, ALUControlD_1;

  reg RegWriteE_0, MemWriteE_0, BranchE_0, JumpE_0;
  reg RegWriteE_1, MemWriteE_1, BranchE_1, JumpE_1;
  reg [1:0] ResultSrcE_0, ResultSrcE_1;
  reg RegWriteM_0, MemWriteM_0;
  reg RegWriteM_1, MemWriteM_1;
  wire BlockIssue1D, PCSrcE_0, PCSrcE_1;

  maindec md_0(
    .op(InstrD_0[6:0]),
    .ResultSrc(ResultSrcD_0),
    .MemWrite(MemWriteD_0),
    .Branch(BranchD_0),
    .ALUSrc(ALUSrcD_0),
    .RegWrite(RegWriteD_0),
    .Jump(JumpD_0),
    .ImmSrc(ImmSrcD_0),
    .ALUOp(ALUOpD_0)
  );

  aludec ad_0(
    .opb5(InstrD_0[5]),
    .funct3(InstrD_0[14:12]),
    .funct7b5(InstrD_0[30]),
    .ALUOp(ALUOpD_0),
    .ALUControl(ALUControlD_0)
  );

  maindec md_1(
    .op(InstrD_1[6:0]),
    .ResultSrc(ResultSrcD_1),
    .MemWrite(MemWriteD_1),
    .Branch(BranchD_1),
    .ALUSrc(ALUSrcD_1),
    .RegWrite(RegWriteD_1),
    .Jump(JumpD_1),
    .ImmSrc(ImmSrcD_1),
    .ALUOp(ALUOpD_1)
  );

  aludec ad_1(
    .opb5(InstrD_1[5]),
    .funct3(InstrD_1[14:12]),
    .funct7b5(InstrD_1[30]),
    .ALUOp(ALUOpD_1),
    .ALUControl(ALUControlD_1)
  );

  // La emision consulta al hazard antes de dejar salir I1
  dual_issue issue(
    .InstrD_0(InstrD_0), .InstrD_1(InstrD_1),
    .RegWriteD_0(RegWriteD_0), .BranchD_0(BranchD_0), .JumpD_0(JumpD_0),
    .StallD(StallD), .BlockIssue1D(BlockIssue1D),
    .Issue1D(Issue1D)
  );

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RegWriteE_0 <= 0;
      ResultSrcE_0 <= 0;
      MemWriteE_0 <= 0;
      BranchE_0 <= 0;
      ALUSrcE_0 <= 0;
      JumpE_0 <= 0;
      ALUControlE_0 <= 0;
    end else if (FlushE) begin
      RegWriteE_0 <= 0;
      ResultSrcE_0 <= 0;
      MemWriteE_0 <= 0;
      BranchE_0 <= 0;
      ALUSrcE_0 <= 0;
      JumpE_0 <= 0;
      ALUControlE_0 <= 0;
    end else begin
      RegWriteE_0 <= RegWriteD_0;
      ResultSrcE_0 <= ResultSrcD_0;
      MemWriteE_0 <= MemWriteD_0;
      BranchE_0 <= BranchD_0;
      ALUSrcE_0 <= ALUSrcD_0;
      JumpE_0 <= JumpD_0;
      ALUControlE_0 <= ALUControlD_0;
    end
  end

  // La via 1 recibe una burbuja si no emite
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RegWriteE_1 <= 0;
      ResultSrcE_1 <= 0;
      MemWriteE_1 <= 0;
      BranchE_1 <= 0;
      ALUSrcE_1 <= 0;
      JumpE_1 <= 0;
      ALUControlE_1 <= 0;
    end else if (FlushE || !Issue1D) begin
      RegWriteE_1 <= 0;
      ResultSrcE_1 <= 0;
      MemWriteE_1 <= 0;
      BranchE_1 <= 0;
      ALUSrcE_1 <= 0;
      JumpE_1 <= 0;
      ALUControlE_1 <= 0;
    end else begin
      RegWriteE_1 <= RegWriteD_1;
      ResultSrcE_1 <= ResultSrcD_1;
      MemWriteE_1 <= MemWriteD_1;
      BranchE_1 <= BranchD_1;
      ALUSrcE_1 <= ALUSrcD_1;
      JumpE_1 <= JumpD_1;
      ALUControlE_1 <= ALUControlD_1;
    end
  end

  // Unico recurso de saltos: la Issue Unit garantiza que en EX hay
  // a lo sumo un beq o jal, en cualquiera de las dos vias
  assign PCSrcE_0 = (BranchE_0 & ZeroE_0) | JumpE_0;
  assign PCSrcE_1 = (BranchE_1 & ZeroE_1) | JumpE_1;
  assign PCSrcE = PCSrcE_0 | PCSrcE_1;
  assign BranchSelE = BranchE_1 | JumpE_1;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RegWriteM_0 <= 0;
      ResultSrcM_0 <= 0;
      MemWriteM_0 <= 0;
      RegWriteM_1 <= 0;
      ResultSrcM_1 <= 0;
      MemWriteM_1 <= 0;
    end else begin
      RegWriteM_0 <= RegWriteE_0;
      ResultSrcM_0 <= ResultSrcE_0;
      MemWriteM_0 <= MemWriteE_0;
      // Si salta I0, I1 (mas joven, del camino equivocado) se anula.
      // Si salta I1, I0 es mas antigua y continua
      if (PCSrcE_0) begin
        RegWriteM_1 <= 0;
        ResultSrcM_1 <= 0;
        MemWriteM_1 <= 0;
      end else begin
        RegWriteM_1 <= RegWriteE_1;
        ResultSrcM_1 <= ResultSrcE_1;
        MemWriteM_1 <= MemWriteE_1;
      end
    end
  end

  // Un solo puerto de datos: lo toma la via que tenga lw o sw
  assign MemSelM = MemWriteM_1 | (ResultSrcM_1 == 2'b01);
  assign MemWriteM = MemSelM ? MemWriteM_1 : MemWriteM_0;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RegWriteW_0 <= 0;
      ResultSrcW_0 <= 0;
      RegWriteW_1 <= 0;
      ResultSrcW_1 <= 0;
    end else begin
      RegWriteW_0 <= RegWriteM_0;
      ResultSrcW_0 <= ResultSrcM_0;
      RegWriteW_1 <= RegWriteM_1;
      ResultSrcW_1 <= ResultSrcM_1;
    end
  end

  // El hazard recibe las fuentes y los destinos de ambas vias
  dual_hazard hazard(
    .opD_0(InstrD_0[6:0]), .opD_1(InstrD_1[6:0]),
    .Rs1D_0(InstrD_0[19:15]), .Rs2D_0(InstrD_0[24:20]),
    .Rs1D_1(InstrD_1[19:15]), .Rs2D_1(InstrD_1[24:20]),
    .Rs1E_0(Rs1E_0), .Rs2E_0(Rs2E_0),
    .Rs1E_1(Rs1E_1), .Rs2E_1(Rs2E_1),
    .RdE_0(RdE_0), .RdE_1(RdE_1), .RdM_0(RdM_0), .RdW_0(RdW_0),
    .RdM_1(RdM_1), .RdW_1(RdW_1),
    .RegWriteE_0(RegWriteE_0), .RegWriteE_1(RegWriteE_1), .RegWriteM_0(RegWriteM_0),
    .RegWriteW_0(RegWriteW_0),
    .RegWriteM_1(RegWriteM_1), .RegWriteW_1(RegWriteW_1),
    .ResultSrcE_0(ResultSrcE_0), .ResultSrcE_1(ResultSrcE_1),
    .ResultSrcM_0(ResultSrcM_0), .ResultSrcM_1(ResultSrcM_1),
    .PCSrcE(PCSrcE),
    .ForwardAE_0(ForwardAE_0), .ForwardBE_0(ForwardBE_0),
    .ForwardAE_1(ForwardAE_1), .ForwardBE_1(ForwardBE_1),
    .StallF(StallF), .StallD(StallD), .BlockIssue1D(BlockIssue1D),
    .FlushD(FlushD), .FlushE(FlushE)
  );
endmodule
