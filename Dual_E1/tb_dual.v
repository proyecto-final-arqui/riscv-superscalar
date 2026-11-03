`timescale 1ns/1ps

// Ejecuta un programa en el pipeline Single-Issue y en el Dual-Issue
// con el mismo reloj, y compara registros y memoria al final
module comparar #(parameter MEMFILE = "program1.mem",
                  parameter TRACE = 0) (
    output reg done,
    output reg [31:0] errors
);
  reg clk, reset;
  wire [31:0] WriteData_s, DataAdr_s, WriteData_d, DataAdr_d;
  wire MemWrite_s, MemWrite_d;
  integer i, cycles, end_s, end_d, dual_cycles, regroups;
  integer dual_hist[0:127], regroup_hist[0:127];

  top_pipeline #(.MEMFILE(MEMFILE)) single(
    .clk(clk), .reset(reset),
    .WriteDataM(WriteData_s), .DataAdrM(DataAdr_s), .MemWriteM(MemWrite_s)
  );

  dual_top #(.MEMFILE(MEMFILE)) dual(
    .clk(clk), .reset(reset),
    .WriteDataM(WriteData_d), .DataAdrM(DataAdr_d), .MemWriteM(MemWrite_d)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (!reset) begin
      cycles = cycles + 1;

      // Ciclo de la ultima escritura util (registro distinto de x0 o memoria)
      if ((single.rv.c.RegWriteW && single.rv.dp.RdW != 0) || MemWrite_s)
        end_s = cycles;
      if ((dual.rv.c.RegWriteW_0 && dual.rv.dp.RdW_0 != 0) ||
          (dual.rv.c.RegWriteW_1 && dual.rv.dp.RdW_1 != 0) || MemWrite_d)
        end_d = cycles;

      // Emision doble: las dos instrucciones del par salen juntas
      if (dual.rv.c.Issue1D && !dual.rv.c.FlushD)
        dual_cycles = dual_cycles + 1;
      // Emision parcial: la joven se queda y se reagrupa
      if (dual.rv.dp.ValidD && !dual.rv.dp.LoadPairD &&
          !dual.rv.c.StallD && !dual.rv.c.FlushD)
        regroups = regroups + 1;

      dual_hist[cycles] = dual_cycles;
      regroup_hist[cycles] = regroups;

      if (TRACE)
        $display("%4d | ID PC=%3d I0=%h I1=%h | issue1=%b stall=%b flush=%b | fwd0=%b/%b fwd1=%b/%b",
                 cycles, dual.rv.dp.PCD, dual.rv.dp.InstrD_0, dual.rv.dp.InstrD_1,
                 dual.rv.c.Issue1D, dual.rv.c.StallD, dual.rv.c.FlushD,
                 dual.rv.c.ForwardAE_0, dual.rv.c.ForwardBE_0,
                 dual.rv.c.ForwardAE_1, dual.rv.c.ForwardBE_1);
    end
  end

  initial begin
    clk = 0;
    reset = 1;
    done = 0;
    errors = 0;
    cycles = 0;
    end_s = 0;
    end_d = 0;
    dual_cycles = 0;
    regroups = 0;

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

    // Solo cuenta lo emitido hasta el final del programa: una instruccion
    // pasa de ID a WB en 3 ciclos
    $display("%0s: single %0d ciclos, dual %0d ciclos | %0d emisiones dobles, %0d reagrupamientos | %0s",
             MEMFILE, end_s, end_d, dual_hist[end_d - 3], regroup_hist[end_d - 3],
             errors == 0 ? "MISMO RESULTADO" : "DIFERENTE");
    done = 1;
  end
endmodule

module tb_dual;
  wire done1, done2, done3, done4, done5;
  wire [31:0] err1, err2, err3, err4, err5;

  comparar #(.MEMFILE("program1.mem")) p1(.done(done1), .errors(err1));
  comparar #(.MEMFILE("program2.mem")) p2(.done(done2), .errors(err2));
  comparar #(.MEMFILE("program3.mem")) p3(.done(done3), .errors(err3));
  comparar #(.MEMFILE("program4.mem")) p4(.done(done4), .errors(err4));
  comparar #(.MEMFILE("program5.mem"), .TRACE(1)) p5(.done(done5), .errors(err5));

  initial begin
    wait (done1 && done2 && done3 && done4 && done5);
    if (err1 + err2 + err3 + err4 + err5 == 0)
      $display("DUAL: CORRECTO en los 5 programas");
    else
      $display("DUAL: %0d ERRORES", err1 + err2 + err3 + err4 + err5);
    $finish;
  end
endmodule
