module dual_top #(parameter MEMFILE = "program1.mem") (
    input clk, reset,
    output [31:0] WriteDataM, DataAdrM,
    output MemWriteM
);

  wire [31:0] PCF, InstrF_0, InstrF_1, ReadDataM;

  dual_riscv rv(
    .clk(clk), .reset(reset),
    .PCF(PCF), .InstrF_0(InstrF_0), .InstrF_1(InstrF_1),
    .MemWriteM(MemWriteM),
    .DataAdrM(DataAdrM), .WriteDataM(WriteDataM),
    .ReadDataM(ReadDataM)
  );

  // Dual Fetch
  dual_fetch #(.MEMFILE(MEMFILE)) imem(
    .a(PCF), .rd_0(InstrF_0), .rd_1(InstrF_1)
  );

  // Un solo puerto de datos
  dmem dmem(
    .clk(clk), .we(MemWriteM),
    .a(DataAdrM), .wd(WriteDataM), .rd(ReadDataM)
  );
endmodule
