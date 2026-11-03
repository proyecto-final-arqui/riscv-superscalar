`timescale 1ns/1ps

// Guarda las formas de onda de Dual Fetch y Dual Decode en dual_wave.vcd
module tb_wave;
  parameter MEMFILE = "program1.mem";

  reg clk, reset;
  wire [31:0] WriteDataM, DataAdrM;
  wire MemWriteM;

  dual_top #(.MEMFILE(MEMFILE)) dual(
    .clk(clk), .reset(reset),
    .WriteDataM(WriteDataM), .DataAdrM(DataAdrM), .MemWriteM(MemWriteM)
  );

  always #5 clk = ~clk;

  initial begin
    $dumpfile("dual_wave.vcd");
    $dumpvars(0, clk, reset);
    $dumpvars(0, dual.rv.dp.PCF, dual.rv.dp.InstrF_0, dual.rv.dp.InstrF_1);
    $dumpvars(0, dual.rv.dp.PCD, dual.rv.dp.InstrD_0, dual.rv.dp.InstrD_1);
    $dumpvars(0, dual.rv.c.RegWriteD_0, dual.rv.c.RegWriteD_1);
    $dumpvars(0, dual.rv.c.ALUControlD_0, dual.rv.c.ALUControlD_1);
    $dumpvars(0, dual.rv.c.Issue1D, dual.rv.dp.PCNextF);

    clk = 0;
    reset = 1;
    #22 reset = 0;
    #300 $finish;
  end
endmodule
