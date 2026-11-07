module dual_riscv(
    input clk, reset,
    output [31:0] PCF,
    input [31:0] InstrF_0, InstrF_1,
    output MemWriteM,
    output [31:0] DataAdrM, WriteDataM,
    input [31:0] ReadDataM
);

  wire [31:0] InstrD_0, InstrD_1, PCTargetE;
  wire [4:0] Rs1E_0, Rs2E_0, Rs1E_1, Rs2E_1;
  // RdE_1 permite detectar dependencias con una carga de la segunda via
  wire [4:0] RdE_0, RdE_1, RdM_0, RdW_0, RdM_1, RdW_1;
  wire [1:0] ImmSrcD_0, ImmSrcD_1;
  wire [1:0] ResultSrcM_0, ResultSrcM_1, ResultSrcW_0, ResultSrcW_1;
  wire [2:0] ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1;
  wire [2:0] ALUControlE_0, ALUControlE_1;
  wire ALUSrcE_0, ALUSrcE_1, ZeroE_0, ZeroE_1, PCSrcE;
  wire Issue1D, MemSelM, RegWriteW_0, RegWriteW_1;
  wire StallF, StallD, FlushD, FlushE;

  dual_decode c(
    .clk(clk), .reset(reset),
    .InstrD_0(InstrD_0), .InstrD_1(InstrD_1),
    .ZeroE_0(ZeroE_0),
    .Rs1E_0(Rs1E_0), .Rs2E_0(Rs2E_0),
    .Rs1E_1(Rs1E_1), .Rs2E_1(Rs2E_1),
    .RdE_0(RdE_0), .RdE_1(RdE_1), .RdM_0(RdM_0), .RdW_0(RdW_0),
    .RdM_1(RdM_1), .RdW_1(RdW_1),
    .Issue1D(Issue1D),
    .ForwardAE_0(ForwardAE_0), .ForwardBE_0(ForwardBE_0),
    .ForwardAE_1(ForwardAE_1), .ForwardBE_1(ForwardBE_1),
    .StallF(StallF), .StallD(StallD),
    .FlushD(FlushD), .FlushE(FlushE),
    .ImmSrcD_0(ImmSrcD_0), .ImmSrcD_1(ImmSrcD_1),
    .ALUSrcE_0(ALUSrcE_0), .ALUSrcE_1(ALUSrcE_1),
    .ALUControlE_0(ALUControlE_0), .ALUControlE_1(ALUControlE_1),
    .PCSrcE(PCSrcE),
    .MemWriteM(MemWriteM), .MemSelM(MemSelM),
    .ResultSrcM_0(ResultSrcM_0), .ResultSrcM_1(ResultSrcM_1),
    .RegWriteW_0(RegWriteW_0), .RegWriteW_1(RegWriteW_1),
    .ResultSrcW_0(ResultSrcW_0), .ResultSrcW_1(ResultSrcW_1)
  );

  dual_datapath dp(
    .clk(clk), .reset(reset),
    .ImmSrcD_0(ImmSrcD_0), .ImmSrcD_1(ImmSrcD_1),
    .Issue1D(Issue1D),
    .ALUSrcE_0(ALUSrcE_0), .ALUSrcE_1(ALUSrcE_1),
    .ALUControlE_0(ALUControlE_0), .ALUControlE_1(ALUControlE_1),
    .ZeroE_0(ZeroE_0), .ZeroE_1(ZeroE_1),
    .PCTargetE(PCTargetE), .PCSrcE(PCSrcE),
    .ResultSrcM_0(ResultSrcM_0), .ResultSrcM_1(ResultSrcM_1), .MemSelM(MemSelM),
    .RegWriteW_0(RegWriteW_0), .RegWriteW_1(RegWriteW_1),
    .ResultSrcW_0(ResultSrcW_0), .ResultSrcW_1(ResultSrcW_1),
    .StallF(StallF), .StallD(StallD),
    .FlushD(FlushD), .FlushE(FlushE),
    .ForwardAE_0(ForwardAE_0), .ForwardBE_0(ForwardBE_0),
    .ForwardAE_1(ForwardAE_1), .ForwardBE_1(ForwardBE_1),
    .InstrD_0(InstrD_0), .InstrD_1(InstrD_1),
    .Rs1E_0(Rs1E_0), .Rs2E_0(Rs2E_0),
    .Rs1E_1(Rs1E_1), .Rs2E_1(Rs2E_1), .RdE_0(RdE_0), .RdE_1(RdE_1),
    .RdM_0(RdM_0), .RdW_0(RdW_0), .RdM_1(RdM_1), .RdW_1(RdW_1),
    .PCF(PCF), .InstrF_0(InstrF_0), .InstrF_1(InstrF_1),
    .DataAdrM(DataAdrM), .WriteDataM(WriteDataM),
    .ReadDataM(ReadDataM)
  );
endmodule
