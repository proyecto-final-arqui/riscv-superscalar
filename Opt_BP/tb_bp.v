`timescale 1ns/1ps

// Ejecuta un programa en las tres arquitecturas con el mismo reloj:
// (A) Single-Issue, (B) Dual-Issue y (C) Dual-Issue con predictor.
// Comprueba que B y C dejan los mismos registros y memoria que A, que C
// completa las mismas instrucciones en el mismo orden que A, y mide ciclos,
// saltos y fallos de prediccion. NINSTR es la cantidad de instrucciones
// del programa (los NOP del final no se cuentan como completadas).
module comparar_bp #(parameter MEMFILE = "program1.mem",
                     parameter NINSTR = 25) (
    output reg done,
    output reg [31:0] errors
);
  reg clk, reset;
  wire [31:0] wd_s, da_s, wd_d, da_d, wd_p, da_p;
  wire mw_s, mw_d, mw_p;
  integer i, cycles, end_s, end_d, end_p;
  integer ns, np, saltos, fallos, flush_d;
  reg [31:0] pc_s[0:511], pc_p[0:511], in_s[0:511], in_p[0:511];
  reg ValidE_0, ValidE_1;
  reg [31:0] InstrE_0, InstrE_1;

  top_pipeline #(.MEMFILE(MEMFILE)) single(.clk(clk), .reset(reset),
    .WriteDataM(wd_s), .DataAdrM(da_s), .MemWriteM(mw_s));
  dual_top #(.MEMFILE(MEMFILE)) dual(.clk(clk), .reset(reset),
    .WriteDataM(wd_d), .DataAdrM(da_d), .MemWriteM(mw_d));
  bp_top #(.MEMFILE(MEMFILE)) bp(.clk(clk), .reset(reset),
    .WriteDataM(wd_p), .DataAdrM(da_p), .MemWriteM(mw_p));

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (reset) begin
      ValidE_0 = 0;
      ValidE_1 = 0;
    end else begin
      cycles = cycles + 1;

      // Ciclo de la ultima escritura util, con el mismo criterio en las tres
      if ((single.rv.c.RegWriteW && single.rv.dp.RdW != 0) || mw_s)
        end_s = cycles;
      if ((dual.rv.c.RegWriteW_0 && dual.rv.dp.RdW_0 != 0) ||
          (dual.rv.c.RegWriteW_1 && dual.rv.dp.RdW_1 != 0) || mw_d)
        end_d = cycles;
      if ((bp.rv.c.RegWriteW_0 && bp.rv.dp.RdW_0 != 0) ||
          (bp.rv.c.RegWriteW_1 && bp.rv.dp.RdW_1 != 0) || mw_p)
        end_p = cycles;

      // Saltos resueltos en EX y fallos de prediccion (C); saltos tomados (B)
      if (bp.rv.c.CtrlE)
        saltos = saltos + 1;
      if (bp.rv.dp.RedirectE)
        fallos = fallos + 1;
      if (dual.rv.c.PCSrcE)
        flush_d = flush_d + 1;

      // Instrucciones que pasan de EX a MEM (ya no se pueden anular)
      if (single.rv.dp.InstrE != 0 && single.rv.dp.PCE < 4 * NINSTR) begin
        pc_s[ns] = single.rv.dp.PCE;
        in_s[ns] = single.rv.dp.InstrE;
        ns = ns + 1;
      end
      if (ValidE_0 && bp.rv.dp.PCE_0 < 4 * NINSTR) begin
        pc_p[np] = bp.rv.dp.PCE_0;
        in_p[np] = InstrE_0;
        np = np + 1;
      end
      if (ValidE_1 && !bp.rv.dp.MisE_0 && bp.rv.dp.PCE_1 < 4 * NINSTR) begin
        pc_p[np] = bp.rv.dp.PCE_1;
        in_p[np] = InstrE_1;
        np = np + 1;
      end
      ValidE_0 = (bp.rv.dp.InstrD_0 != 0) && !bp.rv.c.FlushE;
      ValidE_1 = (bp.rv.dp.InstrD_0 != 0) && bp.rv.c.Issue1D && !bp.rv.c.FlushE;
      InstrE_0 = bp.rv.dp.InstrD_0;
      InstrE_1 = bp.rv.dp.InstrD_1;
    end
  end

  initial begin
    clk = 0; reset = 1; done = 0; errors = 0; cycles = 0;
    end_s = 0; end_d = 0; end_p = 0; ns = 0; np = 0;
    saltos = 0; fallos = 0; flush_d = 0;

    #22 reset = 0;
    repeat (200) @(posedge clk);
    #1;

    for (i = 0; i < 32; i = i + 1) begin
      if (dual.rv.dp.rf.rf[i] !== single.rv.dp.rf.rf[i]) begin
        errors = errors + 1;
        $display("%0s: x%0d = %0d en dual, %0d en single", MEMFILE, i,
                 $signed(dual.rv.dp.rf.rf[i]), $signed(single.rv.dp.rf.rf[i]));
      end
      if (bp.rv.dp.rf.rf[i] !== single.rv.dp.rf.rf[i]) begin
        errors = errors + 1;
        $display("%0s: x%0d = %0d con predictor, %0d en single", MEMFILE, i,
                 $signed(bp.rv.dp.rf.rf[i]), $signed(single.rv.dp.rf.rf[i]));
      end
    end
    for (i = 0; i < 64; i = i + 1) begin
      if (dual.dmem.RAM[i] !== single.dmem.RAM[i]) begin
        errors = errors + 1;
        $display("%0s: mem[%0d] distinta en dual", MEMFILE, i * 4);
      end
      if (bp.dmem.RAM[i] !== single.dmem.RAM[i]) begin
        errors = errors + 1;
        $display("%0s: mem[%0d] distinta con predictor", MEMFILE, i * 4);
      end
    end
    if (ns != np) begin
      errors = errors + 1;
      $display("%0s: single completa %0d instrucciones y el predictor %0d",
               MEMFILE, ns, np);
    end
    for (i = 0; i < ns && i < np; i = i + 1)
      if (pc_s[i] !== pc_p[i] || in_s[i] !== in_p[i]) begin
        errors = errors + 1;
        if (errors < 6)
          $display("%0s: posicion %0d: PC=%0d en single, PC=%0d con predictor",
                   MEMFILE, i, pc_s[i], pc_p[i]);
      end

    $display("%-13s | instr %3d | ciclos S %3d  D %3d  P %3d | saltos %2d, fallos %2d, flushes D %2d | %0s",
             MEMFILE, ns, end_s, end_d, end_p, saltos, fallos, flush_d,
             errors == 0 ? "MISMO RESULTADO Y ORDEN" : "DIFERENTE");
    done = 1;
  end
endmodule

module tb_bp;
  wire d1, d2, d3, d4, d5, d6, d7;
  wire [31:0] e1, e2, e3, e4, e5, e6, e7;

  comparar_bp #(.MEMFILE("program1.mem"), .NINSTR(25)) p1(.done(d1), .errors(e1));
  comparar_bp #(.MEMFILE("program2.mem"), .NINSTR(20)) p2(.done(d2), .errors(e2));
  comparar_bp #(.MEMFILE("program3.mem"), .NINSTR(24)) p3(.done(d3), .errors(e3));
  comparar_bp #(.MEMFILE("program4.mem"), .NINSTR(25)) p4(.done(d4), .errors(e4));
  comparar_bp #(.MEMFILE("program5.mem"), .NINSTR(39)) p5(.done(d5), .errors(e5));
  comparar_bp #(.MEMFILE("program6.mem"), .NINSTR(25)) p6(.done(d6), .errors(e6));
  comparar_bp #(.MEMFILE("program7.mem"), .NINSTR(13)) p7(.done(d7), .errors(e7));

  initial begin
    wait (d1 && d2 && d3 && d4 && d5 && d6 && d7);
    if (e1 + e2 + e3 + e4 + e5 + e6 + e7 == 0)
      $display("PREDICTOR: CORRECTO en los 7 programas");
    else
      $display("PREDICTOR: %0d ERRORES", e1 + e2 + e3 + e4 + e5 + e6 + e7);
    $finish;
  end
endmodule
