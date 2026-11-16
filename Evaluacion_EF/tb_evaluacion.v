`timescale 1ns/1ps

// Evaluacion de la entrega final: ejecuta un programa en las tres
// arquitecturas con el mismo reloj:
//   (A) Pipeline Single-Issue, (B) Dual-Issue, (C) Dual-Issue con predictor.
//
// Comprobacion por etapas: cada arquitectura reconstruye su banco de
// registros con las escrituras de WB en el orden del programa. Cuando la
// ultima instruccion de una etapa llega a WB, compara los 32 registros y 64
// palabras de memoria con el estado esperado (EXPFILE, generado por
// rvasm.py) y genera un pulso de comprobacion:
//   <arq>_chk = 1 durante ese ciclo, <arq>_etapa = numero de etapa (0..3),
//   <arq>_ok[k] = 1 si la etapa k coincidio.
//
// Rendimiento: ciclos hasta la ultima escritura util (registro distinto de
// x0 o memoria) e instrucciones retiradas con PC < FIN; el bucle final no se
// cuenta. Tambien cuenta pausas, emisiones dobles, flushes y prediccion.
module evaluar #(parameter MEMFILE = "profesor.mem",
                 parameter EXPFILE = "profesor_esperado.mem",
                 parameter FIN = 356,
                 parameter E0 = 52, parameter E1 = 96,
                 parameter E2 = 224, parameter E3 = 352,
                 parameter BASEW = 384,
                 parameter RUN = 1500) (
    output reg done,
    output reg [31:0] errors
);
  localparam NW = 64;

  reg clk, reset;
  wire [31:0] wd_a, da_a, wd_b, da_b, wd_c, da_c;
  wire mw_a, mw_b, mw_c;
  reg [31:0] esperado[0:4 * (32 + NW) - 1];
  integer cycles, k, r, w, e;

  top_pipeline #(.MEMFILE(MEMFILE)) single(.clk(clk), .reset(reset),
    .WriteDataM(wd_a), .DataAdrM(da_a), .MemWriteM(mw_a));
  dual_top #(.MEMFILE(MEMFILE)) dual(.clk(clk), .reset(reset),
    .WriteDataM(wd_b), .DataAdrM(da_b), .MemWriteM(mw_b));
  bp_top #(.MEMFILE(MEMFILE)) opt(.clk(clk), .reset(reset),
    .WriteDataM(wd_c), .DataAdrM(da_c), .MemWriteM(mw_c));

  always #5 clk = ~clk;

  function integer fin_etapa;
    input [31:0] pc;
    begin
      fin_etapa = (pc == E0) ? 0 : (pc == E1) ? 1 : (pc == E2) ? 2 :
                  (pc == E3) ? 3 : -1;
    end
  endfunction

  // ---------------------------------------------------------------- (A)
  reg [31:0] a_rf[0:31];
  reg a_chk, a_fin;
  reg [1:0] a_etapa;
  reg [3:0] a_ok;
  integer a_err, a_ciclos, a_ret, a_pausas, a_flush;

  // ---------------------------------------------------------------- (B)
  reg [31:0] b_rf[0:31];
  reg b_chk, b_fin;
  reg [1:0] b_etapa;
  reg [3:0] b_ok;
  reg b_vE0, b_vE1, b_vM0, b_vM1, b_vW0, b_vW1;
  integer b_err, b_ciclos, b_ret, b_pausas, b_flush, b_dobles;

  // ---------------------------------------------------------------- (C)
  reg [31:0] c_rf[0:31];
  reg c_chk, c_fin;
  reg [1:0] c_etapa;
  reg [3:0] c_ok;
  reg c_vE0, c_vE1, c_vM0, c_vM1, c_vW0, c_vW1;
  integer c_err, c_ciclos, c_ret, c_pausas, c_flush, c_dobles, c_saltos;

  always @(posedge clk) begin
    if (!reset) begin
      cycles = cycles + 1;
      a_chk = 0;
      b_chk = 0;
      c_chk = 0;

      // ================================================ (A) Single-Issue
      if ((single.rv.c.RegWriteW && single.rv.dp.RdW != 0) || mw_a)
        a_ciclos = cycles;
      if (single.rv.dp.InstrE != 0 && single.rv.dp.PCE < FIN)
        a_ret = a_ret + 1;
      if (!a_fin && single.rv.StallD)
        a_pausas = a_pausas + 1;
      if (!a_fin && single.rv.PCSrcE)
        a_flush = a_flush + 1;
      // Escritura en WB (burbuja: InstrW = 0)
      if (single.rv.dp.InstrW != 0) begin
        if (single.rv.c.RegWriteW && single.rv.dp.RdW != 0)
          a_rf[single.rv.dp.RdW] = single.rv.dp.ResultW;
        e = fin_etapa(single.rv.dp.PCPlus4W - 4);
        if (e >= 0) begin
          k = 0;
          for (r = 1; r < 32; r = r + 1)
            if (a_rf[r] !== esperado[e * (32 + NW) + r]) begin
              k = k + 1;
              $display("A etapa %0d: x%0d = %0d, se esperaba %0d", e, r,
                       $signed(a_rf[r]), $signed(esperado[e * (32 + NW) + r]));
            end
          for (w = 0; w < NW; w = w + 1)
            if (single.dmem.RAM[BASEW + w] !== esperado[e * (32 + NW) + 32 + w]) begin
              k = k + 1;
              $display("A etapa %0d: M[x1+%0d] = %0d, se esperaba %0d", e, 4 * w,
                       $signed(single.dmem.RAM[BASEW + w]),
                       $signed(esperado[e * (32 + NW) + 32 + w]));
            end
          a_chk = 1;
          a_etapa = e;
          if (k == 0) a_ok[e] = 1;
          a_err = a_err + k;
          if (e == 3) a_fin = 1;
        end
      end

      // ================================================ (B) Dual-Issue
      if ((dual.rv.c.RegWriteW_0 && dual.rv.dp.RdW_0 != 0) ||
          (dual.rv.c.RegWriteW_1 && dual.rv.dp.RdW_1 != 0) || mw_b)
        b_ciclos = cycles;
      if (b_vE0 && dual.rv.dp.PCE_0 < FIN)
        b_ret = b_ret + 1;
      if (b_vE1 && !dual.rv.c.PCSrcE_0 && dual.rv.dp.PCE_1 < FIN)
        b_ret = b_ret + 1;
      if (!b_fin && dual.rv.c.StallD)
        b_pausas = b_pausas + 1;
      if (!b_fin && dual.rv.c.PCSrcE)
        b_flush = b_flush + 1;
      if (!b_fin && dual.rv.c.Issue1D && !dual.rv.c.FlushE)
        b_dobles = b_dobles + 1;
      // WB en el orden del programa: primero la via 0, luego la via 1
      for (k = 0; k < 2; k = k + 1)
        if (k == 0 ? b_vW0 : b_vW1) begin
          if (k == 0 && dual.rv.c.RegWriteW_0 && dual.rv.dp.RdW_0 != 0)
            b_rf[dual.rv.dp.RdW_0] = dual.rv.dp.ResultW_0;
          if (k == 1 && dual.rv.c.RegWriteW_1 && dual.rv.dp.RdW_1 != 0)
            b_rf[dual.rv.dp.RdW_1] = dual.rv.dp.ResultW_1;
          e = fin_etapa((k == 0 ? dual.rv.dp.PCPlus4W_0 : dual.rv.dp.PCPlus4W_1) - 4);
          if (e >= 0) begin
            w = 0;
            for (r = 1; r < 32; r = r + 1)
              if (b_rf[r] !== esperado[e * (32 + NW) + r]) begin
                w = w + 1;
                $display("B etapa %0d: x%0d = %0d, se esperaba %0d", e, r,
                         $signed(b_rf[r]), $signed(esperado[e * (32 + NW) + r]));
              end
            for (r = 0; r < NW; r = r + 1)
              if (dual.dmem.RAM[BASEW + r] !== esperado[e * (32 + NW) + 32 + r]) begin
                w = w + 1;
                $display("B etapa %0d: M[x1+%0d] distinta", e, 4 * r);
              end
            b_chk = 1;
            b_etapa = e;
            if (w == 0) b_ok[e] = 1;
            b_err = b_err + w;
            if (e == 3) b_fin = 1;
          end
        end
      // Validez de cada via en EX, MEM y WB (I1 anulada si salta I0)
      b_vW0 = b_vM0;
      b_vW1 = b_vM1;
      b_vM0 = b_vE0;
      b_vM1 = b_vE1 && !dual.rv.c.PCSrcE_0;
      b_vE0 = (dual.rv.dp.InstrD_0 != 0) && !dual.rv.c.FlushE;
      b_vE1 = (dual.rv.dp.InstrD_0 != 0) && dual.rv.c.Issue1D && !dual.rv.c.FlushE;

      // ================================================ (C) con predictor
      if ((opt.rv.c.RegWriteW_0 && opt.rv.dp.RdW_0 != 0) ||
          (opt.rv.c.RegWriteW_1 && opt.rv.dp.RdW_1 != 0) || mw_c)
        c_ciclos = cycles;
      if (c_vE0 && opt.rv.dp.PCE_0 < FIN)
        c_ret = c_ret + 1;
      if (c_vE1 && !opt.rv.dp.MisE_0 && opt.rv.dp.PCE_1 < FIN)
        c_ret = c_ret + 1;
      if (!c_fin && opt.rv.c.StallD)
        c_pausas = c_pausas + 1;
      if (!c_fin && opt.rv.dp.RedirectE)
        c_flush = c_flush + 1;
      if (!c_fin && opt.rv.c.Issue1D && !opt.rv.c.FlushE)
        c_dobles = c_dobles + 1;
      if (!c_fin && opt.rv.c.CtrlE)
        c_saltos = c_saltos + 1;
      for (k = 0; k < 2; k = k + 1)
        if (k == 0 ? c_vW0 : c_vW1) begin
          if (k == 0 && opt.rv.c.RegWriteW_0 && opt.rv.dp.RdW_0 != 0)
            c_rf[opt.rv.dp.RdW_0] = opt.rv.dp.ResultW_0;
          if (k == 1 && opt.rv.c.RegWriteW_1 && opt.rv.dp.RdW_1 != 0)
            c_rf[opt.rv.dp.RdW_1] = opt.rv.dp.ResultW_1;
          e = fin_etapa((k == 0 ? opt.rv.dp.PCPlus4W_0 : opt.rv.dp.PCPlus4W_1) - 4);
          if (e >= 0) begin
            w = 0;
            for (r = 1; r < 32; r = r + 1)
              if (c_rf[r] !== esperado[e * (32 + NW) + r]) begin
                w = w + 1;
                $display("C etapa %0d: x%0d = %0d, se esperaba %0d", e, r,
                         $signed(c_rf[r]), $signed(esperado[e * (32 + NW) + r]));
              end
            for (r = 0; r < NW; r = r + 1)
              if (opt.dmem.RAM[BASEW + r] !== esperado[e * (32 + NW) + 32 + r]) begin
                w = w + 1;
                $display("C etapa %0d: M[x1+%0d] distinta", e, 4 * r);
              end
            c_chk = 1;
            c_etapa = e;
            if (w == 0) c_ok[e] = 1;
            c_err = c_err + w;
            if (e == 3) c_fin = 1;
          end
        end
      c_vW0 = c_vM0;
      c_vW1 = c_vM1;
      c_vM0 = c_vE0;
      c_vM1 = c_vE1 && !opt.rv.dp.MisE_0;
      c_vE0 = (opt.rv.dp.InstrD_0 != 0) && !opt.rv.c.FlushE;
      c_vE1 = (opt.rv.dp.InstrD_0 != 0) && opt.rv.c.Issue1D && !opt.rv.c.FlushE;
    end
  end

  initial begin
    $readmemh(EXPFILE, esperado);
    for (r = 0; r < 32; r = r + 1) begin
      a_rf[r] = 0;
      b_rf[r] = 0;
      c_rf[r] = 0;
    end
    clk = 0; reset = 1; done = 0; errors = 0; cycles = 0;
    a_chk = 0; a_fin = 0; a_etapa = 0; a_ok = 0; a_err = 0;
    a_ciclos = 0; a_ret = 0; a_pausas = 0; a_flush = 0;
    b_chk = 0; b_fin = 0; b_etapa = 0; b_ok = 0; b_err = 0;
    b_ciclos = 0; b_ret = 0; b_pausas = 0; b_flush = 0; b_dobles = 0;
    c_chk = 0; c_fin = 0; c_etapa = 0; c_ok = 0; c_err = 0;
    c_ciclos = 0; c_ret = 0; c_pausas = 0; c_flush = 0; c_dobles = 0; c_saltos = 0;
    b_vE0 = 0; b_vE1 = 0; b_vM0 = 0; b_vM1 = 0; b_vW0 = 0; b_vW1 = 0;
    c_vE0 = 0; c_vE1 = 0; c_vM0 = 0; c_vM1 = 0; c_vW0 = 0; c_vW1 = 0;

    #22 reset = 0;
    repeat (RUN) @(posedge clk);
    #1;

    errors = a_err + b_err + c_err;
    if (a_ok != 4'hf || b_ok != 4'hf || c_ok != 4'hf) begin
      errors = errors + 1;
      $display("%0s: etapas comprobadas A=%b B=%b C=%b (falta alguna)", MEMFILE,
               a_ok, b_ok, c_ok);
    end
    if (a_ret != b_ret || a_ret != c_ret) begin
      errors = errors + 1;
      $display("%0s: instrucciones retiradas distintas: A=%0d B=%0d C=%0d",
               MEMFILE, a_ret, b_ret, c_ret);
    end

    $display("");
    $display("==== %0s ====", MEMFILE);
    $display("Etapas comprobadas (bit k = etapa k): A=%b  B=%b  C=%b", a_ok, b_ok, c_ok);
    $display("Indicador              Pipeline   Dual-Issue  Optimizado");
    $display("Ciclos totales         %8d   %10d  %10d", a_ciclos, b_ciclos, c_ciclos);
    $display("Instrucciones retiradas%8d   %10d  %10d", a_ret, b_ret, c_ret);
    $display("CPI x1000              %8d   %10d  %10d", 1000 * a_ciclos / a_ret,
             1000 * b_ciclos / b_ret, 1000 * c_ciclos / c_ret);
    $display("IPC x1000              %8d   %10d  %10d", 1000 * a_ret / a_ciclos,
             1000 * b_ret / b_ciclos, 1000 * c_ret / c_ciclos);
    $display("Speedup vs pipeline x1000 %5d   %10d  %10d", 1000,
             1000 * a_ciclos / b_ciclos, 1000 * a_ciclos / c_ciclos);
    $display("Speedup C vs B x1000                            %10d", 1000 * b_ciclos / c_ciclos);
    $display("Pausas (StallD)        %8d   %10d  %10d", a_pausas, b_pausas, c_pausas);
    $display("Flushes                %8d   %10d  %10d", a_flush, b_flush, c_flush);
    $display("Emisiones dobles                   %10d  %10d", b_dobles, c_dobles);
    $display("Saltos resueltos / fallos de prediccion (C): %0d / %0d", c_saltos, c_flush);
    $display("%0s", errors == 0 ? "RESULTADO: CORRECTO en las tres arquitecturas" :
                                  "RESULTADO: HAY ERRORES");
    done = 1;
  end
endmodule

// Programa del profesor: etapas A, B, C y D (PCs de rvasm.py)
module tb_profesor;
  wire done;
  wire [31:0] errors;
  evaluar #(.MEMFILE("profesor.mem"), .EXPFILE("profesor_esperado.mem"),
            .FIN(356), .E0(52), .E1(96), .E2(224), .E3(352),
            .BASEW(384), .RUN(1500)) ev(.done(done), .errors(errors));
  initial begin
    wait (done);
    $finish;
  end
`ifdef VCD
  // Con Icarus: iverilog -DVCD ... guarda las ondas en tb_profesor.vcd
  initial begin
    $dumpfile("tb_profesor.vcd");
    $dumpvars(0, tb_profesor);
  end
`endif
endmodule

// Programa propio: etapas 1, 2, 3 y 4 (PCs de rvasm.py)
module tb_propio;
  wire done;
  wire [31:0] errors;
  evaluar #(.MEMFILE("propio.mem"), .EXPFILE("propio_esperado.mem"),
            .FIN(284), .E0(52), .E1(136), .E2(200), .E3(280),
            .BASEW(256), .RUN(1500)) ev(.done(done), .errors(errors));
  initial begin
    wait (done);
    $finish;
  end
`ifdef VCD
  initial begin
    $dumpfile("tb_propio.vcd");
    $dumpvars(0, tb_propio);
  end
`endif
endmodule
