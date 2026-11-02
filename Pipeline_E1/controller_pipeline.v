module controller_pipeline(
    input clk, reset,
    input [6:0] opD,
    input [2:0] funct3D,
    input funct7b5D,
    input ZeroE,
    input [4:0] Rs1D, Rs2D,
    input [4:0] Rs1E, Rs2E,
    input [4:0] RdE, RdM, RdW,
    output [1:0] ForwardAE, ForwardBE,
    output StallF, StallD,
    output FlushD, FlushE,
    output [1:0] ImmSrcD,
    output reg ALUSrcE,
    output reg [2:0] ALUControlE,
    output reg RegWriteE,
    output reg [1:0] ResultSrcE,
    output reg JumpE,
    output PCSrcE,
    output reg MemWriteM,
    output reg RegWriteM,
    output reg [1:0] ResultSrcM,
    output reg RegWriteW,
    output reg [1:0] ResultSrcW
);

  wire RegWriteD, MemWriteD, BranchD, ALUSrcD, JumpD;
  wire [1:0] ResultSrcD, ALUOpD;
  wire [2:0] ALUControlD;
  reg MemWriteE, BranchE;

  // Decodifica la instruccion en ID
  maindec md(
    .op(opD),
    .ResultSrc(ResultSrcD),
    .MemWrite(MemWriteD),
    .Branch(BranchD),
    .ALUSrc(ALUSrcD),
    .RegWrite(RegWriteD),
    .Jump(JumpD),
    .ImmSrc(ImmSrcD),
    .ALUOp(ALUOpD)
  );

  aludec ad(
    .opb5(opD[5]),
    .funct3(funct3D),
    .funct7b5(funct7b5D),
    .ALUOp(ALUOpD),
    .ALUControl(ALUControlD)
  );

  // Guarda el control de EX
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RegWriteE <= 0;
      ResultSrcE <= 0;
      MemWriteE <= 0;
      BranchE <= 0;
      ALUSrcE <= 0;
      JumpE <= 0;
      ALUControlE <= 0;
    end else if (FlushE) begin
      RegWriteE <= 0;
      ResultSrcE <= 0;
      MemWriteE <= 0;
      BranchE <= 0;
      ALUSrcE <= 0;
      JumpE <= 0;
      ALUControlE <= 0;
    end else begin
      RegWriteE <= RegWriteD;
      ResultSrcE <= ResultSrcD;
      MemWriteE <= MemWriteD;
      BranchE <= BranchD;
      ALUSrcE <= ALUSrcD;
      JumpE <= JumpD;
      ALUControlE <= ALUControlD;
    end
  end

  // Decide el salto en EX
  assign PCSrcE = (BranchE & ZeroE) | JumpE;

  // Guarda el control de MEM
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RegWriteM <= 0;
      ResultSrcM <= 0;
      MemWriteM <= 0;
    end else begin
      RegWriteM <= RegWriteE;
      ResultSrcM <= ResultSrcE;
      MemWriteM <= MemWriteE;
    end
  end

  // Guarda el control de WB
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      RegWriteW <= 0;
      ResultSrcW <= 0;
    end else begin
      RegWriteW <= RegWriteM;
      ResultSrcW <= ResultSrcM;
    end
  end

  // Conecta la deteccion de hazards
  hazard_unit hazard(
    .opD(opD),
    .Rs1D(Rs1D), .Rs2D(Rs2D),
    .Rs1E(Rs1E), .Rs2E(Rs2E),
    .RdE(RdE), .RdM(RdM), .RdW(RdW),
    .RegWriteE(RegWriteE), .RegWriteM(RegWriteM),
    .RegWriteW(RegWriteW),
    .ResultSrcE(ResultSrcE), .ResultSrcM(ResultSrcM),
    .PCSrcE(PCSrcE),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .StallF(StallF), .StallD(StallD),
    .FlushD(FlushD), .FlushE(FlushE)
  );
endmodule
