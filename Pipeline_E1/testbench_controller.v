`timescale 1ns/1ps

module testbench_controller;
  reg clk, reset, ZeroE;
  reg [31:0] InstrD;
  reg [4:0] Rs1E, Rs2E, RdE, RdM, RdW;
  wire [1:0] ImmSrcD, ResultSrcE, ResultSrcM, ResultSrcW;
  wire [1:0] ForwardAE, ForwardBE;
  wire [2:0] ALUControlE;
  wire ALUSrcE, RegWriteE, JumpE, PCSrcE;
  wire MemWriteM, RegWriteM, RegWriteW;
  wire StallF, StallD, FlushD, FlushE;
  integer tests, errors;

  controller_pipeline dut(
    .clk(clk), .reset(reset),
    .opD(InstrD[6:0]), .funct3D(InstrD[14:12]),
    .funct7b5D(InstrD[30]), .ZeroE(ZeroE),
    .Rs1D(InstrD[19:15]), .Rs2D(InstrD[24:20]),
    .Rs1E(Rs1E), .Rs2E(Rs2E),
    .RdE(RdE), .RdM(RdM), .RdW(RdW),
    .ImmSrcD(ImmSrcD), .ALUSrcE(ALUSrcE),
    .ALUControlE(ALUControlE), .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE), .JumpE(JumpE), .PCSrcE(PCSrcE),
    .MemWriteM(MemWriteM), .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM), .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE)
  );

  always #5 clk = ~clk;

  // Simula los numeros de registro de las etapas
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      Rs1E <= 0;
      Rs2E <= 0;
      RdE <= 0;
      RdM <= 0;
      RdW <= 0;
    end else begin
      if (FlushE) begin
        Rs1E <= 0;
        Rs2E <= 0;
        RdE <= 0;
      end else begin
        Rs1E <= InstrD[19:15];
        Rs2E <= InstrD[24:20];
        RdE <= InstrD[11:7];
      end
      RdM <= RdE;
      RdW <= RdM;
    end
  end

  // Comprueba una condicion
  task check;
    input passed;
    begin
      tests = tests + 1;
      if (passed !== 1'b1) begin
        errors = errors + 1;
        $display("Error en comprobacion %0d", tests);
      end
    end
  endtask

  initial begin
    clk = 0;
    reset = 1;
    ZeroE = 0;
    InstrD = 0;
    tests = 0;
    errors = 0;

    // El reset limpia el control
    #2;
    check({RegWriteE, RegWriteM, RegWriteW, MemWriteM, PCSrcE} === 5'b0);

    // lw x5, 0(x0)
    @(negedge clk);
    reset = 0;
    InstrD = 32'h00002283;
    @(posedge clk); #1;
    check((RegWriteE === 1'b1) && (ResultSrcE === 2'b01) &&
          (ImmSrcD === 2'b00) && (RdE === 5'd5));

    // add x6, x5, x5 necesita el dato de lw
    @(negedge clk);
    InstrD = 32'h00528333;
    #1;
    check({StallF, StallD, FlushD, FlushE} === 4'b1101);

    // FlushE limpia EX y deja avanzar a lw
    @(posedge clk); #1;
    check((RegWriteE === 1'b0) && (RdE === 5'd0) &&
          (RegWriteM === 1'b1) && (ResultSrcM === 2'b01) &&
          (RdM === 5'd5) && (StallD === 1'b0));

    // Conserva ADD durante la pausa y luego usa WB
    @(posedge clk); #1;
    check((RegWriteE === 1'b1) && (ResultSrcE === 2'b00) &&
          (RdW === 5'd5) && ({ForwardAE, ForwardBE} === 4'b0101));

    // sw x6, 0(x0) recibe su dato desde MEM
    @(negedge clk);
    InstrD = 32'h00602023;
    @(posedge clk); #1;
    check((ForwardBE === 2'b10) && (ALUSrcE === 1'b1) &&
          (ALUControlE === 3'b000) && (MemWriteM === 1'b0));

    // La escritura se habilita al llegar a MEM
    @(negedge clk);
    InstrD = 0;
    @(posedge clk); #1;
    check((MemWriteM === 1'b1) && (RegWriteM === 1'b0) &&
          (RegWriteW === 1'b1) && (ResultSrcW === 2'b00));

    // beq x0, x0, +8 con Zero simulado en cero
    @(negedge clk);
    InstrD = 32'h00000463;
    ZeroE = 0;
    @(posedge clk); #1;
    check((PCSrcE === 1'b0) && (ALUControlE === 3'b001) &&
          ({FlushD, FlushE} === 2'b00));

    // Zero activa el salto y la limpieza
    ZeroE = 1;
    #1;
    check((PCSrcE === 1'b1) &&
          ({StallF, StallD, FlushD, FlushE} === 4'b0011));

    // Un store del camino incorrecto no entra a EX
    @(negedge clk);
    InstrD = 32'h00602223;
    @(posedge clk); #1;
    check((PCSrcE === 1'b0) && (RegWriteE === 1'b0) &&
          (RdE === 5'b0) && (JumpE === 1'b0));

    // Simula la limpieza de la instruccion en ID
    @(negedge clk);
    InstrD = 0;
    ZeroE = 0;
    @(posedge clk); #1;
    check(MemWriteM === 1'b0);

    // jal x7, +8 activa la limpieza
    @(negedge clk);
    InstrD = 32'h008003ef;
    @(posedge clk); #1;
    check((JumpE === 1'b1) && (PCSrcE === 1'b1) &&
          (RegWriteE === 1'b1) && (ResultSrcE === 2'b10));

    // Anula ADDI y conserva el JAL anterior
    @(negedge clk);
    InstrD = 32'h00100413;
    @(posedge clk); #1;
    check((RegWriteE === 1'b0) && (JumpE === 1'b0) &&
          (RegWriteM === 1'b1) && (ResultSrcM === 2'b10));

    // addi x8, x7, 1 selecciona el resultado de JAL
    @(negedge clk);
    InstrD = 32'h00138413;
    @(posedge clk); #1;
    check((ForwardAE === 2'b01) && (RegWriteW === 1'b1) &&
          (ResultSrcW === 2'b10) && (RegWriteE === 1'b1));

    // addi x9, x8, 1 usa forwarding de MEM
    @(negedge clk);
    InstrD = 32'h00140493;
    @(posedge clk); #1;
    check((ForwardAE === 2'b10) && (RdM === 5'd8));

    // addi x9, x9, 1 vuelve a escribir x9
    @(negedge clk);
    InstrD = 32'h00148493;
    @(posedge clk); #1;
    check((ForwardAE === 2'b10) && (RdM === 5'd9));

    // addi x10, x9, 1 debe elegir el x9 mas reciente
    @(negedge clk);
    InstrD = 32'h00148513;
    @(posedge clk); #1;
    check((RdM === 5'd9) && (RdW === 5'd9) &&
          (ForwardAE === 2'b10));

    // Reset durante la ejecucion
    reset = 1;
    #1;
    check({RegWriteE, RegWriteM, RegWriteW, MemWriteM,
           PCSrcE, StallF, StallD, FlushD, FlushE} === 9'b0);

    if (errors == 0)
      $display("Controller y Hazard Unit: %0d comprobaciones correctas", tests);
    else
      $display("Controller y Hazard Unit: %0d errores", errors);
    $finish;
  end

  // Evita una espera sin fin
  initial begin
    #500;
    $display("Error: tiempo agotado");
    $finish;
  end
endmodule
