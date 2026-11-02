`timescale 1ns/1ps

// Ejecuta un programa en el pipeline Single-Issue y en el Dual-Issue
// preliminar con el mismo reloj, y compara registros y memoria al final
module comparar #(parameter MEMFILE = "program1.mem",
                         parameter TRACE = 0) (
    output reg done,
    output reg [31:0] errors
);
  reg clk, reset;
  wire [31:0] WriteData_s, DataAdr_s, WriteData_d, DataAdr_d;
  wire MemWrite_s, MemWrite_d;
  integer i, cycles, pairs, regroups, lane1_writes;

  top_pipeline #(.MEMFILE(MEMFILE)) single(
    .clk(clk), .reset(reset),
    .WriteDataM(WriteData_s), .DataAdrM(DataAdr_s), .MemWriteM(MemWrite_s)
  );

  dual_top #(.MEMFILE(MEMFILE)) dual(
    .clk(clk), .reset(reset),
    .WriteDataM(WriteData_d), .DataAdrM(DataAdr_d), .MemWriteM(MemWrite_d)
  );

  always #5 clk = ~clk;

  // Evidencia de Dual Fetch y Dual Decode
  always @(posedge clk) begin
    if (!reset) begin
      cycles = cycles + 1;
      if (dual.rv.dp.ValidD) pairs = pairs + 1;
      if (dual.rv.dp.ValidD && !dual.rv.dp.LoadPairD && !dual.rv.c.StallD)
        regroups = regroups + 1;
      if (dual.rv.c.RegWriteW_1) lane1_writes = lane1_writes + 1;

      // El store debe salir en el mismo ciclo en las dos arquitecturas
      if (MemWrite_s !== MemWrite_d ||
          (MemWrite_s && (DataAdr_s !== DataAdr_d || WriteData_s !== WriteData_d))) begin
        errors = errors + 1;
        $display("%0s %0t: store distinto (single %0d<-%0d, dual %0d<-%0d)",
                 MEMFILE, $time, DataAdr_s, WriteData_s, DataAdr_d, WriteData_d);
      end

      if (TRACE)
        $display("%4d | IF PC=%3d I0=%h I1=%h | ID PC=%3d I0=%h I1=%h | dec0 RW=%b ALU=%b imm=%b | dec1 RW=%b ALU=%b imm=%b | issue1=%b",
                 cycles, dual.rv.dp.PCF, dual.rv.dp.InstrF_0, dual.rv.dp.InstrF_1,
                 dual.rv.dp.PCD, dual.rv.dp.InstrD_0, dual.rv.dp.InstrD_1,
                 dual.rv.c.RegWriteD_0, dual.rv.c.ALUControlD_0, dual.rv.c.ImmSrcD_0,
                 dual.rv.c.RegWriteD_1, dual.rv.c.ALUControlD_1, dual.rv.c.ImmSrcD_1,
                 dual.rv.c.Issue1D);
    end
  end

  initial begin
    clk = 0;
    reset = 1;
    done = 0;
    errors = 0;
    cycles = 0;
    pairs = 0;
    regroups = 0;
    lane1_writes = 0;

    #22 reset = 0;
    repeat (80) @(posedge clk);
    #1;

    for (i = 0; i < 32; i = i + 1)
      if (dual.rv.dp.rf.rf[i] !== single.rv.dp.rf.rf[i]) begin
        errors = errors + 1;
        $display("%0s: x%0d = %0d en dual, %0d en single", MEMFILE, i,
                 $signed(dual.rv.dp.rf.rf[i]), $signed(single.rv.dp.rf.rf[i]));
      end
    for (i = 0; i < 64; i = i + 1)
      if (dual.dmem.RAM[i] !== single.dmem.RAM[i]) begin
        errors = errors + 1;
        $display("%0s: mem[%0d] = %0d en dual, %0d en single", MEMFILE, i * 4,
                 $signed(dual.dmem.RAM[i]), $signed(single.dmem.RAM[i]));
      end

    // En E1 la via 1 no emite: nunca debe escribir
    if (lane1_writes != 0) begin
      errors = errors + 1;
      $display("%0s: la via 1 escribio %0d veces", MEMFILE, lane1_writes);
    end

    $display("%0s: %0d ciclos, %0d con par en ID, %0d reagrupamientos, %0s",
             MEMFILE, cycles, pairs, regroups,
             errors == 0 ? "IGUAL AL SINGLE-ISSUE" : "DIFERENTE");
    done = 1;
  end
endmodule

module tb_dual;
  wire done1, done2, done3, done4;
  wire [31:0] err1, err2, err3, err4;

  comparar #(.MEMFILE("program1.mem"), .TRACE(1)) p1(.done(done1), .errors(err1));
  comparar #(.MEMFILE("program2.mem")) p2(.done(done2), .errors(err2));
  comparar #(.MEMFILE("program3.mem")) p3(.done(done3), .errors(err3));
  comparar #(.MEMFILE("program4.mem")) p4(.done(done4), .errors(err4));

  initial begin
    wait (done1 && done2 && done3 && done4);
    if (err1 + err2 + err3 + err4 == 0)
      $display("DUAL E1: CORRECTO en los 4 programas");
    else
      $display("DUAL E1: %0d ERRORES", err1 + err2 + err3 + err4);
    $finish;
  end
endmodule
