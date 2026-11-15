// Dual-Issue con predictor y sus memorias (las mismas del Dual-Issue)
module bp_top #(parameter MEMFILE = "program1.mem") (
    input clk, reset,
    output [31:0] WriteDataM, DataAdrM,
    output MemWriteM
);

  wire [31:0] PCF, InstrF_0, InstrF_1, ReadDataM;

  bp_riscv rv(
    .clk(clk), .reset(reset),
    .PCF(PCF), .InstrF_0(InstrF_0), .InstrF_1(InstrF_1),
    .MemWriteM(MemWriteM),
    .DataAdrM(DataAdrM), .WriteDataM(WriteDataM),
    .ReadDataM(ReadDataM)
  );

  dual_fetch #(.MEMFILE(MEMFILE)) imem(
    .a(PCF), .rd_0(InstrF_0), .rd_1(InstrF_1)
  );

  dmem dmem(
    .clk(clk), .we(MemWriteM),
    .a(DataAdrM), .wd(WriteDataM), .rd(ReadDataM)
  );
endmodule
