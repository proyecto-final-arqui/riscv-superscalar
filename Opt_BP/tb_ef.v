`timescale 1ns/1ps

// Banco de evaluacion final (EF): compara (A) Pipeline Single-Issue,
// (B) Dual-Issue sin predictor y (C) Dual-Issue con predictor BTB 2-bits.
// Mide ciclos totales, instrucciones retiradas (excluyendo `fin`), CPI, IPC,
// speedup vs A y vs B, saltos, aciertos/fallos del predictor, stalls y doble emision.
// Para `program_profesor.mem` verifica ademas los estados de cierre A, B, C y D.
module eval_ef #(
    parameter MEMFILE = "program_profesor.mem",
    parameter FIN_PC  = 356,
    parameter MAX_CYC = 1000,
    parameter CHECK_PROF = 0
) (
    output reg done,
    output reg [31:0] errors
);
  reg clk, reset;
  wire [31:0] wd_s, da_s, wd_d, da_d, wd_p, da_p;
  wire mw_s, mw_d, mw_p;

  integer i, cycles;
  integer end_s, end_d, end_p;
  integer ret_s, ret_d, ret_p;
  integer stalls_s, stalls_d, stalls_p;
  integer flushes_s, flushes_d, fallos_p, saltos_p, dual_d, dual_p;

  reg ValidE_d0, ValidE_d1, ValidE_p0, ValidE_p1;
  reg [31:0] InstrE_d0, InstrE_d1, InstrE_p0, InstrE_p1;

  // Banderas de comprobacion por etapa (utiles en waveforms para el programa del profesor)
  reg chk_A_ok_s, chk_B_ok_s, chk_C_ok_s, chk_D_ok_s;
  reg chk_A_ok_d, chk_B_ok_d, chk_C_ok_d, chk_D_ok_d;
  reg chk_A_ok_p, chk_B_ok_p, chk_C_ok_p, chk_D_ok_p;
  reg trig_A_s, trig_B_s, trig_C_s, trig_D_s;
  reg trig_A_d, trig_B_d, trig_C_d, trig_D_d;
  reg trig_A_p, trig_B_p, trig_C_p, trig_D_p;
  reg regs_C_ok_s, regs_C_ok_d, regs_C_ok_p;

  reg fin_s, fin_d, fin_p;
  reg wait_s, wait_d, wait_p;
  reg done_s, done_d, done_p;

  top_pipeline #(.MEMFILE(MEMFILE)) single(
    .clk(clk), .reset(reset),
    .WriteDataM(wd_s), .DataAdrM(da_s), .MemWriteM(mw_s)
  );
  dual_top #(.MEMFILE(MEMFILE)) dual(
    .clk(clk), .reset(reset),
    .WriteDataM(wd_d), .DataAdrM(da_d), .MemWriteM(mw_d)
  );
  bp_top #(.MEMFILE(MEMFILE)) bp(
    .clk(clk), .reset(reset),
    .WriteDataM(wd_p), .DataAdrM(da_p), .MemWriteM(mw_p)
  );

  always #5 clk = ~clk;

  // Etapas del programa del profesor:
  // etapa_B inicia en PC = 56  -> al llegar PC=56 a WB (o completarse PC=52), etapa A termino
  // etapa_C inicia en PC = 100 -> etapa B termino
  // etapa_D inicia en PC = 228 -> etapa C termino
  // fin     inicia en PC = 356 -> etapa D termino
  always @(posedge clk) begin
    if (reset) begin
      ValidE_d0 <= 0; ValidE_d1 <= 0;
      ValidE_p0 <= 0; ValidE_p1 <= 0;
    end else begin
      cycles = cycles + 1;

      // ---------- A: Pipeline Single-Issue ----------
      if (!done_s && ((single.rv.c.RegWriteW && single.rv.dp.RdW != 0) || mw_s))
        end_s = cycles;
      if (!fin_s) begin
        if (single.rv.dp.InstrE != 0 && single.rv.dp.PCE < FIN_PC)
          ret_s = ret_s + 1;
        if (single.rv.c.StallD)
          stalls_s = stalls_s + 1;
        if (single.rv.c.PCSrcE)
          flushes_s = flushes_s + 1;
        if (single.rv.dp.InstrE != 0 && single.rv.dp.PCE == FIN_PC)
          fin_s = 1;
      end else if (!wait_s) begin
        wait_s = 1;
      end else if (!done_s) begin
        done_s = 1;
      end

      // ---------- B: Dual-Issue sin predictor ----------
      if (!done_d && ((dual.rv.c.RegWriteW_0 && dual.rv.dp.RdW_0 != 0) ||
                      (dual.rv.c.RegWriteW_1 && dual.rv.dp.RdW_1 != 0) || mw_d))
        end_d = cycles;
      if (!fin_d) begin
        if (ValidE_d0 && dual.rv.dp.PCE_0 < FIN_PC)
          ret_d = ret_d + 1;
        if (ValidE_d1 && !dual.rv.c.PCSrcE_0 && dual.rv.dp.PCE_1 < FIN_PC)
          ret_d = ret_d + 1;
        if (dual.rv.dp.InstrD_0 != 0 && dual.rv.c.Issue1D && !dual.rv.c.FlushE)
          dual_d = dual_d + 1;
        if (dual.rv.c.StallD)
          stalls_d = stalls_d + 1;
        if (dual.rv.c.PCSrcE)
          flushes_d = flushes_d + 1;
        if ((ValidE_d0 && dual.rv.dp.PCE_0 == FIN_PC) ||
            (ValidE_d1 && !dual.rv.c.PCSrcE_0 && dual.rv.dp.PCE_1 == FIN_PC))
          fin_d = 1;
      end else if (!wait_d) begin
        wait_d = 1;
      end else if (!done_d) begin
        done_d = 1;
      end

      // ---------- C: Dual-Issue con predictor BTB 2-bits ----------
      if (!done_p && ((bp.rv.c.RegWriteW_0 && bp.rv.dp.RdW_0 != 0) ||
                      (bp.rv.c.RegWriteW_1 && bp.rv.dp.RdW_1 != 0) || mw_p))
        end_p = cycles;
      if (!fin_p) begin
        if (ValidE_p0 && bp.rv.dp.PCE_0 < FIN_PC)
          ret_p = ret_p + 1;
        if (ValidE_p1 && !bp.rv.dp.MisE_0 && bp.rv.dp.PCE_1 < FIN_PC)
          ret_p = ret_p + 1;
        if (bp.rv.dp.InstrD_0 != 0 && bp.rv.c.Issue1D && !bp.rv.c.FlushE)
          dual_p = dual_p + 1;
        if (bp.rv.c.StallD)
          stalls_p = stalls_p + 1;
        if (bp.rv.c.CtrlE)
          saltos_p = saltos_p + 1;
        if (bp.rv.dp.RedirectE)
          fallos_p = fallos_p + 1;
        if ((ValidE_p0 && bp.rv.dp.PCE_0 == FIN_PC) ||
            (ValidE_p1 && !bp.rv.dp.MisE_0 && bp.rv.dp.PCE_1 == FIN_PC))
          fin_p = 1;
      end else if (!wait_p) begin
        wait_p = 1;
      end else if (!done_p) begin
        done_p = 1;
      end

      // Seguimiento de instrucciones que entran a EX
      ValidE_d0 <= (dual.rv.dp.InstrD_0 != 0) && !dual.rv.c.FlushE;
      ValidE_d1 <= (dual.rv.dp.InstrD_0 != 0) && dual.rv.c.Issue1D && !dual.rv.c.FlushE;
      InstrE_d0 <= dual.rv.dp.InstrD_0;
      InstrE_d1 <= dual.rv.dp.InstrD_1;

      ValidE_p0 <= (bp.rv.dp.InstrD_0 != 0) && !bp.rv.c.FlushE;
      ValidE_p1 <= (bp.rv.dp.InstrD_0 != 0) && bp.rv.c.Issue1D && !bp.rv.c.FlushE;
      InstrE_p0 <= bp.rv.dp.InstrD_0;
      InstrE_p1 <= bp.rv.dp.InstrD_1;

      // Comprobacion de cierre de etapas A, B, C, D en el programa del profesor.
      // Cada etapa termina con un sw unico a M[x1+8], M[x1+20], M[x1+32] y M[x1+52].
      // Se dispara en el flanco donde ese sw escribe en dmem y se verifica al ciclo siguiente.
      if (CHECK_PROF) begin
        trig_A_s <= (mw_s && da_s == 1544);
        trig_B_s <= (mw_s && da_s == 1556);
        trig_C_s <= (mw_s && da_s == 1568);
        trig_D_s <= (mw_s && da_s == 1588);

        trig_A_d <= (mw_d && da_d == 1544);
        trig_B_d <= (mw_d && da_d == 1556);
        trig_C_d <= (mw_d && da_d == 1568);
        trig_D_d <= (mw_d && da_d == 1588);

        trig_A_p <= (mw_p && da_p == 1544);
        trig_B_p <= (mw_p && da_p == 1556);
        trig_C_p <= (mw_p && da_p == 1568);
        trig_D_p <= (mw_p && da_p == 1588);

        if (trig_A_s && !chk_A_ok_s) begin
          chk_A_ok_s <= (single.rv.dp.rf.rf[1]==1536 && single.rv.dp.rf.rf[5]==11 &&
                         single.rv.dp.rf.rf[6]==5 && single.rv.dp.rf.rf[7]==16 &&
                         single.rv.dp.rf.rf[8]==2 && single.rv.dp.rf.rf[9]==7 &&
                         single.rv.dp.rf.rf[10]==12 &&
                         single.dmem.RAM[384]==11 && single.dmem.RAM[385]==5 &&
                         single.dmem.RAM[386]==12);
          $display("[PROF] Cierre Etapa A en A (Single) a t=%0d ns (ciclo %0d)", $time, cycles);
        end
        if (trig_A_d && !chk_A_ok_d) begin
          chk_A_ok_d <= (dual.rv.dp.rf.rf[1]==1536 && dual.rv.dp.rf.rf[5]==11 &&
                         dual.rv.dp.rf.rf[6]==5 && dual.rv.dp.rf.rf[7]==16 &&
                         dual.rv.dp.rf.rf[8]==2 && dual.rv.dp.rf.rf[9]==7 &&
                         dual.rv.dp.rf.rf[10]==12 &&
                         dual.dmem.RAM[384]==11 && dual.dmem.RAM[385]==5 &&
                         dual.dmem.RAM[386]==12);
          $display("[PROF] Cierre Etapa A en B (Dual)   a t=%0d ns (ciclo %0d)", $time, cycles);
        end
        if (trig_A_p && !chk_A_ok_p) begin
          chk_A_ok_p <= (bp.rv.dp.rf.rf[1]==1536 && bp.rv.dp.rf.rf[5]==11 &&
                         bp.rv.dp.rf.rf[6]==5 && bp.rv.dp.rf.rf[7]==16 &&
                         bp.rv.dp.rf.rf[8]==2 && bp.rv.dp.rf.rf[9]==7 &&
                         bp.rv.dp.rf.rf[10]==12 &&
                         bp.dmem.RAM[384]==11 && bp.dmem.RAM[385]==5 &&
                         bp.dmem.RAM[386]==12);
          $display("[PROF] Cierre Etapa A en C (BTB)    a t=%0d ns (ciclo %0d)", $time, cycles);
        end

        if (trig_B_s && !chk_B_ok_s) begin
          chk_B_ok_s <= (single.rv.dp.rf.rf[11]==11 && single.rv.dp.rf.rf[12]==16 &&
                         single.rv.dp.rf.rf[13]==5 && single.rv.dp.rf.rf[14]==12 &&
                         single.rv.dp.rf.rf[15]==7 && single.rv.dp.rf.rf[16]==7 &&
                         single.rv.dp.rf.rf[17]==16 && single.rv.dp.rf.rf[18]==23 &&
                         single.dmem.RAM[387]==7 && single.dmem.RAM[388]==16 &&
                         single.dmem.RAM[389]==23);
          $display("[PROF] Cierre Etapa B en A (Single) a t=%0d ns (ciclo %0d)", $time, cycles);
        end
        if (trig_B_d && !chk_B_ok_d) begin
          chk_B_ok_d <= (dual.rv.dp.rf.rf[11]==11 && dual.rv.dp.rf.rf[12]==16 &&
                         dual.rv.dp.rf.rf[13]==5 && dual.rv.dp.rf.rf[14]==12 &&
                         dual.rv.dp.rf.rf[15]==7 && dual.rv.dp.rf.rf[16]==7 &&
                         dual.rv.dp.rf.rf[17]==16 && dual.rv.dp.rf.rf[18]==23 &&
                         dual.dmem.RAM[387]==7 && dual.dmem.RAM[388]==16 &&
                         dual.dmem.RAM[389]==23);
          $display("[PROF] Cierre Etapa B en B (Dual)   a t=%0d ns (ciclo %0d)", $time, cycles);
        end
        if (trig_B_p && !chk_B_ok_p) begin
          chk_B_ok_p <= (bp.rv.dp.rf.rf[11]==11 && bp.rv.dp.rf.rf[12]==16 &&
                         bp.rv.dp.rf.rf[13]==5 && bp.rv.dp.rf.rf[14]==12 &&
                         bp.rv.dp.rf.rf[15]==7 && bp.rv.dp.rf.rf[16]==7 &&
                         bp.rv.dp.rf.rf[17]==16 && bp.rv.dp.rf.rf[18]==23 &&
                         bp.dmem.RAM[387]==7 && bp.dmem.RAM[388]==16 &&
                         bp.dmem.RAM[389]==23);
          $display("[PROF] Cierre Etapa B en C (BTB)    a t=%0d ns (ciclo %0d)", $time, cycles);
        end

        if (mw_s && da_s == 1568)
          regs_C_ok_s <= (single.rv.dp.rf.rf[19]==12 && single.rv.dp.rf.rf[20]==12 &&
                          single.rv.dp.rf.rf[21]==24 && single.rv.dp.rf.rf[22]==18 &&
                          single.rv.dp.rf.rf[24]==24 && single.rv.dp.rf.rf[26]==6);
        if (mw_d && da_d == 1568)
          regs_C_ok_d <= (dual.rv.dp.rf.rf[19]==12 && dual.rv.dp.rf.rf[20]==12 &&
                          dual.rv.dp.rf.rf[21]==24 && dual.rv.dp.rf.rf[22]==18 &&
                          dual.rv.dp.rf.rf[24]==24 && dual.rv.dp.rf.rf[26]==6);
        if (mw_p && da_p == 1568)
          regs_C_ok_p <= (bp.rv.dp.rf.rf[19]==12 && bp.rv.dp.rf.rf[20]==12 &&
                          bp.rv.dp.rf.rf[21]==24 && bp.rv.dp.rf.rf[22]==18 &&
                          bp.rv.dp.rf.rf[24]==24 && bp.rv.dp.rf.rf[26]==6);

        if (trig_C_s && !chk_C_ok_s) begin
          chk_C_ok_s <= (regs_C_ok_s &&
                         single.dmem.RAM[390]==24 && single.dmem.RAM[391]==18 &&
                         single.dmem.RAM[392]==24);
          $display("[PROF] Cierre Etapa C en A (Single) a t=%0d ns (ciclo %0d)", $time, cycles);
        end
        if (trig_C_d && !chk_C_ok_d) begin
          chk_C_ok_d <= (regs_C_ok_d &&
                         dual.dmem.RAM[390]==24 && dual.dmem.RAM[391]==18 &&
                         dual.dmem.RAM[392]==24);
          $display("[PROF] Cierre Etapa C en B (Dual)   a t=%0d ns (ciclo %0d)", $time, cycles);
        end
        if (trig_C_p && !chk_C_ok_p) begin
          chk_C_ok_p <= (regs_C_ok_p &&
                         bp.dmem.RAM[390]==24 && bp.dmem.RAM[391]==18 &&
                         bp.dmem.RAM[392]==24);
          $display("[PROF] Cierre Etapa C en C (BTB)    a t=%0d ns (ciclo %0d)", $time, cycles);
        end

        if (trig_D_s && !chk_D_ok_s) begin
          chk_D_ok_s <= (single.rv.dp.rf.rf[27]==1560 && single.rv.dp.rf.rf[28]==74 &&
                         single.rv.dp.rf.rf[29]==4 && single.rv.dp.rf.rf[30]==23 &&
                         single.rv.dp.rf.rf[31]==1 &&
                         single.dmem.RAM[393]==74 && single.dmem.RAM[394]==4 &&
                         single.dmem.RAM[395]==0 && single.dmem.RAM[396]==1 &&
                         single.dmem.RAM[397]==1);
          $display("[PROF] Cierre Etapa D en A (Single) a t=%0d ns (ciclo %0d)", $time, cycles);
        end
        if (trig_D_d && !chk_D_ok_d) begin
          chk_D_ok_d <= (dual.rv.dp.rf.rf[27]==1560 && dual.rv.dp.rf.rf[28]==74 &&
                         dual.rv.dp.rf.rf[29]==4 && dual.rv.dp.rf.rf[30]==23 &&
                         dual.rv.dp.rf.rf[31]==1 &&
                         dual.dmem.RAM[393]==74 && dual.dmem.RAM[394]==4 &&
                         dual.dmem.RAM[395]==0 && dual.dmem.RAM[396]==1 &&
                         dual.dmem.RAM[397]==1);
          $display("[PROF] Cierre Etapa D en B (Dual)   a t=%0d ns (ciclo %0d)", $time, cycles);
        end
        if (trig_D_p && !chk_D_ok_p) begin
          chk_D_ok_p <= (bp.rv.dp.rf.rf[27]==1560 && bp.rv.dp.rf.rf[28]==74 &&
                         bp.rv.dp.rf.rf[29]==4 && bp.rv.dp.rf.rf[30]==23 &&
                         bp.rv.dp.rf.rf[31]==1 &&
                         bp.dmem.RAM[393]==74 && bp.dmem.RAM[394]==4 &&
                         bp.dmem.RAM[395]==0 && bp.dmem.RAM[396]==1 &&
                         bp.dmem.RAM[397]==1);
          $display("[PROF] Cierre Etapa D en C (BTB)    a t=%0d ns (ciclo %0d)", $time, cycles);
        end
      end
    end
  end

  initial begin
    clk = 0; reset = 1; done = 0; errors = 0; cycles = 0;
    end_s = 0; end_d = 0; end_p = 0;
    ret_s = 0; ret_d = 0; ret_p = 0;
    stalls_s = 0; stalls_d = 0; stalls_p = 0;
    flushes_s = 0; flushes_d = 0; fallos_p = 0; saltos_p = 0;
    dual_d = 0; dual_p = 0;
    fin_s = 0; fin_d = 0; fin_p = 0;
    wait_s = 0; wait_d = 0; wait_p = 0;
    done_s = 0; done_d = 0; done_p = 0;
    chk_A_ok_s = 0; chk_B_ok_s = 0; chk_C_ok_s = 0; chk_D_ok_s = 0;
    chk_A_ok_d = 0; chk_B_ok_d = 0; chk_C_ok_d = 0; chk_D_ok_d = 0;
    chk_A_ok_p = 0; chk_B_ok_p = 0; chk_C_ok_p = 0; chk_D_ok_p = 0;
    trig_A_s = 0; trig_B_s = 0; trig_C_s = 0; trig_D_s = 0;
    trig_A_d = 0; trig_B_d = 0; trig_C_d = 0; trig_D_d = 0;
    trig_A_p = 0; trig_B_p = 0; trig_C_p = 0; trig_D_p = 0;
    regs_C_ok_s = 0; regs_C_ok_d = 0; regs_C_ok_p = 0;

    #22 reset = 0;
    repeat (MAX_CYC) @(posedge clk);
    #1;

    // Compara todos los 32 registros y las 512 palabras de memoria
    for (i = 0; i < 32; i = i + 1) begin
      if (dual.rv.dp.rf.rf[i] !== single.rv.dp.rf.rf[i]) begin
        errors = errors + 1;
        $display("%0s ERROR reg x%0d: B=%0d, A=%0d", MEMFILE, i,
                 $signed(dual.rv.dp.rf.rf[i]), $signed(single.rv.dp.rf.rf[i]));
      end
      if (bp.rv.dp.rf.rf[i] !== single.rv.dp.rf.rf[i]) begin
        errors = errors + 1;
        $display("%0s ERROR reg x%0d: C=%0d, A=%0d", MEMFILE, i,
                 $signed(bp.rv.dp.rf.rf[i]), $signed(single.rv.dp.rf.rf[i]));
      end
    end
    for (i = 0; i < 512; i = i + 1) begin
      if (dual.dmem.RAM[i] !== single.dmem.RAM[i]) begin
        errors = errors + 1;
        $display("%0s ERROR mem[%0d]: B=%0d, A=%0d", MEMFILE, i * 4,
                 $signed(dual.dmem.RAM[i]), $signed(single.dmem.RAM[i]));
      end
      if (bp.dmem.RAM[i] !== single.dmem.RAM[i]) begin
        errors = errors + 1;
        $display("%0s ERROR mem[%0d]: C=%0d, A=%0d", MEMFILE, i * 4,
                 $signed(bp.dmem.RAM[i]), $signed(single.dmem.RAM[i]));
      end
    end

    if (ret_s != ret_d || ret_s != ret_p) begin
      errors = errors + 1;
      $display("%0s ERROR instr retiradas: A=%0d, B=%0d, C=%0d", MEMFILE, ret_s, ret_d, ret_p);
    end

    if (CHECK_PROF) begin
      if (!(chk_A_ok_s && chk_B_ok_s && chk_C_ok_s && chk_D_ok_s &&
            chk_A_ok_d && chk_B_ok_d && chk_C_ok_d && chk_D_ok_d &&
            chk_A_ok_p && chk_B_ok_p && chk_C_ok_p && chk_D_ok_p)) begin
        errors = errors + 1;
        $display("ERROR checkpoints profesor A/B/C/D: S=%b%b%b%b D=%b%b%b%b P=%b%b%b%b",
                 chk_A_ok_s, chk_B_ok_s, chk_C_ok_s, chk_D_ok_s,
                 chk_A_ok_d, chk_B_ok_d, chk_C_ok_d, chk_D_ok_d,
                 chk_A_ok_p, chk_B_ok_p, chk_C_ok_p, chk_D_ok_p);
      end
    end

    $display("================================================================================");
    $display("Programa: %0s | Equivalencia A=B=C: %0s (errores=%0d)",
             MEMFILE, (errors == 0) ? "OK" : "FALLO", errors);
    $display("  A (Pipeline)   : instr=%0d, ciclos=%0d, CPI=%0.3f, IPC=%0.3f, stalls=%0d, flushes=%0d",
             ret_s, end_s, (1.0*end_s)/ret_s, (1.0*ret_s)/end_s, stalls_s, flushes_s);
    $display("  B (Dual-Issue) : instr=%0d, ciclos=%0d, CPI=%0.3f, IPC=%0.3f, speedup_vs_A=%0.3f, dual=%0d, stalls=%0d, flushes=%0d",
             ret_d, end_d, (1.0*end_d)/ret_d, (1.0*ret_d)/end_d, (1.0*end_s)/end_d, dual_d, stalls_d, flushes_d);
    $display("  C (Dual+BTB)   : instr=%0d, ciclos=%0d, CPI=%0.3f, IPC=%0.3f, speedup_vs_A=%0.3f, speedup_vs_B=%0.3f, dual=%0d, stalls=%0d, saltos=%0d, fallos=%0d, aciertos=%0d",
             ret_p, end_p, (1.0*end_p)/ret_p, (1.0*ret_p)/end_p, (1.0*end_s)/end_p, (1.0*end_d)/end_p, dual_p, stalls_p, saltos_p, fallos_p, saltos_p - fallos_p);
    if (CHECK_PROF)
      $display("  Checkpoints A-D: A(S=%0b,D=%0b,P=%0b) B(S=%0b,D=%0b,P=%0b) C(S=%0b,D=%0b,P=%0b) D(S=%0b,D=%0b,P=%0b)",
               chk_A_ok_s, chk_A_ok_d, chk_A_ok_p,
               chk_B_ok_s, chk_B_ok_d, chk_B_ok_p,
               chk_C_ok_s, chk_C_ok_d, chk_C_ok_p,
               chk_D_ok_s, chk_D_ok_d, chk_D_ok_p);
    done = 1;
  end
endmodule

module tb_ef;
  wire d_prof, d_p8, d_p7;
  wire [31:0] e_prof, e_p8, e_p7;

  eval_ef #(.MEMFILE("program_profesor.mem"), .FIN_PC(356), .MAX_CYC(900), .CHECK_PROF(1))
    u_prof(.done(d_prof), .errors(e_prof));

  eval_ef #(.MEMFILE("program8.mem"), .FIN_PC(240), .MAX_CYC(1100), .CHECK_PROF(0))
    u_p8(.done(d_p8), .errors(e_p8));

  eval_ef #(.MEMFILE("program7.mem"), .FIN_PC(52), .MAX_CYC(300), .CHECK_PROF(0))
    u_p7(.done(d_p7), .errors(e_p7));

  initial begin
    wait (d_prof && d_p8 && d_p7);
    if (e_prof + e_p8 + e_p7 == 0)
      $display("EVALUACION FINAL: TODOS LOS PROGRAMAS CORRECTOS");
    else
      $display("EVALUACION FINAL: %0d ERRORES", e_prof + e_p8 + e_p7);
    $finish;
  end
endmodule
