module riscv_pipeline(
    input clk, reset,
    output [31:0] PCF,
    input [31:0] InstrF,
    output MemWriteM,
    output [31:0] ALUResultM, WriteDataM,
    input [31:0] ReadDataM
);

  wire [31:0] InstrD, PCTargetE;
  wire [4:0] Rs1E, Rs2E, RdE, RdM, RdW;
  wire [1:0] ImmSrcD, ResultSrcE, ResultSrcM, ResultSrcW;
  wire [1:0] ForwardAE, ForwardBE;
  wire [2:0] ALUControlE;
  wire ALUSrcE, RegWriteE, JumpE, PCSrcE, ZeroE;
  wire RegWriteM, RegWriteW;
  wire StallF, StallD, FlushD, FlushE;

  // Control por etapas con la Hazard Unit adentro
  controller_pipeline c(
    .clk(clk), .reset(reset),
    .opD(InstrD[6:0]), .funct3D(InstrD[14:12]),
    .funct7b5D(InstrD[30]), .ZeroE(ZeroE),
    .Rs1D(InstrD[19:15]), .Rs2D(InstrD[24:20]),
    .Rs1E(Rs1E), .Rs2E(Rs2E),
    .RdE(RdE), .RdM(RdM), .RdW(RdW),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .StallF(StallF), .StallD(StallD),
    .FlushD(FlushD), .FlushE(FlushE),
    .ImmSrcD(ImmSrcD), .ALUSrcE(ALUSrcE),
    .ALUControlE(ALUControlE), .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE), .JumpE(JumpE), .PCSrcE(PCSrcE),
    .MemWriteM(MemWriteM), .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM), .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW)
  );

  datapath_pipeline dp(
    .clk(clk), .reset(reset),
    .ImmSrcD(ImmSrcD),
    .ALUSrcE(ALUSrcE), .ALUControlE(ALUControlE),
    .ZeroE(ZeroE), .PCTargetE(PCTargetE), .PCSrcE(PCSrcE),
    .ResultSrcM(ResultSrcM),
    .RegWriteW(RegWriteW), .ResultSrcW(ResultSrcW),
    .StallF(StallF), .StallD(StallD),
    .FlushD(FlushD), .FlushE(FlushE),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .InstrD(InstrD),
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE), .RdM(RdM), .RdW(RdW),
    .PCF(PCF), .InstrF(InstrF),
    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM),
    .ReadDataM(ReadDataM)
  );
endmodule
