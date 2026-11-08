`timescale 1ns/1ps

// Ejecuta un programa en el Single-Issue y en el Dual-Issue y compara la
// secuencia de instrucciones (PC y palabra de instruccion) que pasan de EX
// a MEM, donde ya no se pueden anular. Si las dos secuencias son iguales, el
// Dual no pierde, no duplica y no reordena instrucciones. NINSTR es la cantidad de instrucciones del
// programa: los NOP que siguen al final no se cuentan
module orden #(parameter MEMFILE = "program1.mem",
               parameter NINSTR = 25,
               parameter TRACE = 0) (
    output reg done,
    output reg [31:0] errors
);
  reg clk, reset;
  wire [31:0] WriteData_s, DataAdr_s, WriteData_d, DataAdr_d;
  wire MemWrite_s, MemWrite_d;
  integer i, ns, nd, cycles;
  reg [31:0] pc_s[0:255], pc_d[0:255], instr_s[0:255], instr_d[0:255];
  reg ValidE_0, ValidE_1;
  reg [31:0] InstrE_0, InstrE_1;

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
    if (reset) begin
      ValidE_0 = 0;
      ValidE_1 = 0;
    end else begin
      cycles = cycles + 1;

      // Single: una burbuja en EX tiene InstrE = 0
      if (single.rv.dp.InstrE != 0 && single.rv.dp.PCE < 4 * NINSTR) begin
        pc_s[ns] = single.rv.dp.PCE;
        instr_s[ns] = single.rv.dp.InstrE;
        ns = ns + 1;
      end

      // Dual: primero la via 0, que es la mas antigua. La via 1 no cuenta
      // si un salto tomado de la via 0 la anula
      if (ValidE_0 && dual.rv.dp.PCE_0 < 4 * NINSTR) begin
        pc_d[nd] = dual.rv.dp.PCE_0;
        instr_d[nd] = InstrE_0;
        nd = nd + 1;
      end
      if (ValidE_1 && !dual.rv.c.PCSrcE_0 && dual.rv.dp.PCE_1 < 4 * NINSTR) begin
        pc_d[nd] = dual.rv.dp.PCE_1;
        instr_d[nd] = InstrE_1;
        nd = nd + 1;
      end

      if (TRACE && dual.rv.dp.InstrD_0 != 0 && dual.rv.dp.PCD < 4 * NINSTR)
        $display("%0s c%0d | ID PC=%0d: I0 %0s | I1 (PC=%0d) %0s", MEMFILE, cycles,
                 dual.rv.dp.PCD,
                 dual.rv.c.FlushD ? "anulada" : (dual.rv.c.StallD ? "en pausa" : "sale"),
                 dual.rv.dp.PCD + 4,
                 dual.rv.c.FlushD ? "anulada" :
                 dual.rv.c.Issue1D ? "sale junto" :
                 dual.rv.c.BlockIssue1D ? "espera (Load-Use de I1)" : "espera");
      if (TRACE && dual.rv.c.PCSrcE)
        $display("%0s c%0d | salto tomado en EX por la via %0d hacia PC=%0d%0s", MEMFILE, cycles,
                 dual.rv.c.BranchSelE, dual.rv.dp.PCTargetE,
                 (dual.rv.c.PCSrcE_0 && ValidE_1) ? ", anula la I1 que iba en EX" : "");

      // El Dual no guarda la instruccion en EX: se copia aqui al pasar de ID a EX.
      // Es valida si hay instruccion en ID y no entra una burbuja
      ValidE_0 = (dual.rv.dp.InstrD_0 != 0) && !dual.rv.c.FlushE;
      ValidE_1 = (dual.rv.dp.InstrD_0 != 0) && dual.rv.c.Issue1D && !dual.rv.c.FlushE;
      InstrE_0 = dual.rv.dp.InstrD_0;
      InstrE_1 = dual.rv.dp.InstrD_1;
    end
  end

  initial begin
    clk = 0;
    reset = 1;
    done = 0;
    errors = 0;
    ns = 0;
    nd = 0;
    cycles = 0;

    #22 reset = 0;
    repeat (90) @(posedge clk);
    #1;

    if (ns != nd) begin
      errors = errors + 1;
      $display("%0s: el single completa %0d instrucciones y el dual %0d", MEMFILE, ns, nd);
    end
    for (i = 0; i < ns && i < nd; i = i + 1)
      if (pc_s[i] !== pc_d[i] || instr_s[i] !== instr_d[i]) begin
        errors = errors + 1;
        $display("%0s: posicion %0d: PC=%0d (%h) en single, PC=%0d (%h) en dual", MEMFILE, i,
                 pc_s[i], instr_s[i], pc_d[i], instr_d[i]);
      end

    $display("%0s: %0d instrucciones completadas | %0s", MEMFILE, nd,
             errors == 0 ? "MISMO ORDEN, SIN PERDIDAS NI DUPLICADOS" : "DIFERENTE");
    done = 1;
  end
endmodule

module tb_orden;
  wire done1, done2, done3, done4, done5, done6;
  wire [31:0] err1, err2, err3, err4, err5, err6;

  orden #(.MEMFILE("program1.mem"), .NINSTR(25)) p1(.done(done1), .errors(err1));
  orden #(.MEMFILE("program2.mem"), .NINSTR(20)) p2(.done(done2), .errors(err2));
  orden #(.MEMFILE("program3.mem"), .NINSTR(24)) p3(.done(done3), .errors(err3));
  orden #(.MEMFILE("program4.mem"), .NINSTR(25)) p4(.done(done4), .errors(err4));
  orden #(.MEMFILE("program5.mem"), .NINSTR(39)) p5(.done(done5), .errors(err5));
  orden #(.MEMFILE("program6.mem"), .NINSTR(25)) p6(.done(done6), .errors(err6));

  initial begin
    wait (done1 && done2 && done3 && done4 && done5 && done6);
    if (err1 + err2 + err3 + err4 + err5 + err6 == 0)
      $display("ORDEN: CORRECTO en los 6 programas");
    else
      $display("ORDEN: %0d ERRORES", err1 + err2 + err3 + err4 + err5 + err6);
    $finish;
  end
endmodule
