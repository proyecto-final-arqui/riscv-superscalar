`timescale 1ns/1ps

module testbench_controller;
  reg clk, reset, ZeroE, FlushE;
  reg [6:0] opD;
  reg [2:0] funct3D;
  reg funct7b5D;
  wire [1:0] ImmSrcD, ResultSrcE, ResultSrcM, ResultSrcW;
  wire [2:0] ALUControlE;
  wire ALUSrcE, RegWriteE, JumpE, PCSrcE;
  wire MemWriteM, RegWriteM, RegWriteW;
  integer errors;

  controller_pipeline dut(
    .clk(clk), .reset(reset),
    .opD(opD), .funct3D(funct3D), .funct7b5D(funct7b5D),
    .ZeroE(ZeroE), .FlushE(FlushE),
    .ImmSrcD(ImmSrcD), .ALUSrcE(ALUSrcE),
    .ALUControlE(ALUControlE), .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE), .JumpE(JumpE), .PCSrcE(PCSrcE),
    .MemWriteM(MemWriteM), .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM), .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW)
  );

  always #5 clk = ~clk;

  initial begin
    $dumpfile("controller.vcd");
    $dumpvars(0, testbench_controller);
    clk = 0;
    reset = 1;
    ZeroE = 0;
    FlushE = 0;
    opD = 0;
    funct3D = 0;
    funct7b5D = 0;
    errors = 0;

    // Comprueba el reset
    #2;
    if ({RegWriteE, RegWriteM, RegWriteW, MemWriteM, PCSrcE} !== 5'b0) begin
      $display("Error: reset");
      errors = errors + 1;
    end

    // addi entra a EX
    @(negedge clk);
    reset = 0;
    opD = 7'b0010011;
    #1;
    if (ImmSrcD !== 2'b00) begin
      $display("Error: inmediato addi");
      errors = errors + 1;
    end
    @(posedge clk); #1;
    if ({RegWriteE, ALUSrcE, ALUControlE, ResultSrcE} !== 7'b1_1_000_00) begin
      $display("Error: addi en EX");
      errors = errors + 1;
    end

    // lw entra mientras addi avanza
    @(negedge clk);
    opD = 7'b0000011;
    funct3D = 3'b010;
    @(posedge clk); #1;
    if ({RegWriteE, ResultSrcE, RegWriteM, ResultSrcM, RegWriteW}
        !== 7'b1_01_1_00_0) begin
      $display("Error: avance de addi y lw");
      errors = errors + 1;
    end

    // Una burbuja deja avanzar a lw
    @(negedge clk);
    opD = 7'b0100011;
    FlushE = 1;
    @(posedge clk); #1;
    if ({RegWriteE, JumpE, PCSrcE, RegWriteM, ResultSrcM, MemWriteM,
         RegWriteW, ResultSrcW} !== 10'b0_0_0_1_01_0_1_00) begin
      $display("Error: burbuja o avance de lw");
      errors = errors + 1;
    end

    // El store anulado no escribe
    @(negedge clk);
    FlushE = 0;
    opD = 0;
    @(posedge clk); #1;
    if ({RegWriteM, MemWriteM, RegWriteW, ResultSrcW} !== 5'b0_0_1_01) begin
      $display("Error: store anulado o lw en WB");
      errors = errors + 1;
    end

    // Un store valido escribe en MEM
    @(negedge clk);
    opD = 7'b0100011;
    @(posedge clk); #1;
    if (MemWriteM !== 1'b0) begin
      $display("Error: store escribe antes de MEM");
      errors = errors + 1;
    end
    @(negedge clk);
    opD = 0;
    @(posedge clk); #1;
    if ({MemWriteM, RegWriteM} !== 2'b10) begin
      $display("Error: store en MEM");
      errors = errors + 1;
    end

    // beq usa el Zero de EX
    @(negedge clk);
    opD = 7'b1100011;
    funct3D = 0;
    ZeroE = 1;
    #1;
    if (PCSrcE !== 1'b0) begin
      $display("Error: branch decide desde ID");
      errors = errors + 1;
    end
    @(posedge clk); #1;
    if ({PCSrcE, ALUControlE} !== 4'b1_001) begin
      $display("Error: beq tomado");
      errors = errors + 1;
    end
    ZeroE = 0;
    #1;
    if (PCSrcE !== 1'b0) begin
      $display("Error: beq no tomado");
      errors = errors + 1;
    end

    // jal salta sin depender de Zero
    @(negedge clk);
    opD = 7'b1101111;
    @(posedge clk); #1;
    if ({JumpE, PCSrcE, RegWriteE, ResultSrcE} !== 5'b1_1_1_10) begin
      $display("Error: jal en EX");
      errors = errors + 1;
    end

    // Anula el siguiente salto
    @(negedge clk);
    FlushE = 1;
    @(posedge clk); #1;
    if ({JumpE, PCSrcE, RegWriteE, RegWriteM, ResultSrcM} !== 6'b0_0_0_1_10) begin
      $display("Error: salto anulado o jal en MEM");
      errors = errors + 1;
    end
    @(negedge clk);
    opD = 0;
    FlushE = 0;
    @(posedge clk); #1;
    if ({RegWriteW, ResultSrcW} !== 3'b1_10) begin
      $display("Error: jal en WB");
      errors = errors + 1;
    end

    // Reset con instrucciones en curso
    reset = 1;
    #1;
    if ({RegWriteE, RegWriteM, RegWriteW, MemWriteM, JumpE, PCSrcE} !== 6'b0) begin
      $display("Error: reset durante ejecucion");
      errors = errors + 1;
    end

    if (errors == 0)
      $display("Prueba del controller correcta");
    else
      $display("Prueba del controller con %0d errores", errors);
    $finish;
  end

  // Evita una espera sin fin
  initial begin
    #1000;
    $display("Error: tiempo agotado");
    $finish;
  end
endmodule
