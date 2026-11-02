`timescale 1ns/1ps

// Programa 1: ISA sin dependencias
module testbench_program1;
  reg clk, reset;
  wire [31:0] WriteDataM, DataAdrM;
  wire MemWriteM;
  reg [31:0] exp_reg[0:31];
  reg [31:0] exp_mem[0:63];
  integer i, errors, stalls, flushes;
  integer fwdA_M, fwdA_W, fwdB_M, fwdB_W, fwd_total;

  top_pipeline #(.MEMFILE("program1.mem")) dut(
    .clk(clk), .reset(reset),
    .WriteDataM(WriteDataM), .DataAdrM(DataAdrM), .MemWriteM(MemWriteM)
  );

  always #5 clk = ~clk;

  // Registra cada accion de la Hazard Unit
  always @(posedge clk) begin
    if (!reset) begin
      if (dut.rv.c.StallD) begin
        stalls = stalls + 1;
        $display("%0t: Load-Use, pausa la instruccion de PC=%0d", $time, dut.rv.dp.PCD);
      end
      if (dut.rv.c.PCSrcE) begin
        flushes = flushes + 1;
        $display("%0t: salto tomado en PC=%0d hacia %0d, se anulan ID y EX",
                 $time, dut.rv.dp.PCE, dut.rv.dp.PCTargetE);
      end
      if (dut.rv.c.ForwardAE == 2'b10) fwdA_M = fwdA_M + 1;
      if (dut.rv.c.ForwardAE == 2'b01) fwdA_W = fwdA_W + 1;
      if (dut.rv.c.ForwardBE == 2'b10) fwdB_M = fwdB_M + 1;
      if (dut.rv.c.ForwardBE == 2'b01) fwdB_W = fwdB_W + 1;
      if (dut.rv.c.ForwardAE != 0 || dut.rv.c.ForwardBE != 0)
        $display("%0t: forwarding en PC=%0d, ForwardAE=%b ForwardBE=%b",
                 $time, dut.rv.dp.PCE, dut.rv.c.ForwardAE, dut.rv.c.ForwardBE);
    end
  end

  // Compara un contador de eventos
  task check_count;
    input [8*24-1:0] name;
    input integer value, expected;
    input passed;
    begin
      if (!passed) begin
        errors = errors + 1;
        $display("Error: %0s = %0d, se esperaba %0d", name, value, expected);
      end else
        $display("%0s: %0d", name, value);
    end
  endtask

  initial begin
    clk = 0;
    reset = 1;
    errors = 0;
    stalls = 0;
    flushes = 0;
    fwdA_M = 0;
    fwdA_W = 0;
    fwdB_M = 0;
    fwdB_W = 0;

    // Valores esperados; el resto debe quedar en cero
    for (i = 0; i < 32; i = i + 1) exp_reg[i] = 0;
    for (i = 0; i < 64; i = i + 1) exp_mem[i] = 0;
    exp_reg[1] = 32'd5;
    exp_reg[2] = 32'd12;
    exp_reg[3] = -32'd3;
    exp_reg[4] = 32'd85;
    exp_reg[5] = 32'd17;
    exp_reg[6] = -32'd7;
    exp_reg[7] = 32'd4;
    exp_reg[8] = 32'd93;
    exp_reg[9] = 32'd1;
    exp_reg[11] = 32'd5;
    exp_reg[12] = 32'd53;
    exp_reg[13] = 32'd1;
    exp_reg[15] = 32'd17;
    exp_reg[16] = -32'd7;
    exp_reg[17] = 32'd64;
    exp_reg[18] = 32'd1;
    exp_reg[19] = 32'd2;
    exp_mem[2] = -32'd3; // dir 8
    exp_mem[16] = 32'd17; // dir 64
    exp_mem[17] = -32'd7; // dir 68

    #22 reset = 0;
    repeat (80) @(posedge clk);
    #1;

    // Revisa todo el banco de registros y la memoria de datos
    for (i = 0; i < 32; i = i + 1)
      if (dut.rv.dp.rf.rf[i] !== exp_reg[i]) begin
        errors = errors + 1;
        $display("Error: x%0d = %0d, se esperaba %0d",
                 i, $signed(dut.rv.dp.rf.rf[i]), $signed(exp_reg[i]));
      end
    for (i = 0; i < 64; i = i + 1)
      if (dut.dmem.RAM[i] !== exp_mem[i]) begin
        errors = errors + 1;
        $display("Error: mem[%0d] = %0d, se esperaba %0d",
                 i * 4, $signed(dut.dmem.RAM[i]), $signed(exp_mem[i]));
      end

    fwd_total = fwdA_M + fwdA_W + fwdB_M + fwdB_W;
    check_count("pausas", stalls, 0, stalls == 0);
    check_count("saltos tomados", flushes, 0, flushes == 0);
    check_count("forwardings", fwd_total, 0, fwd_total == 0);

    if (errors == 0)
      $display("PROGRAMA 1 (ISA sin dependencias): CORRECTO");
    else
      $display("PROGRAMA 1 (ISA sin dependencias): %0d ERRORES", errors);
    $finish;
  end
endmodule
