`timescale 1ns/1ps

module testbench_hazard;
  reg [6:0] opD;
  reg [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW;
  reg RegWriteE, RegWriteM, RegWriteW;
  reg [1:0] ResultSrcE, ResultSrcM;
  reg PCSrcE;
  wire [1:0] ForwardAE, ForwardBE;
  wire StallF, StallD, FlushD, FlushE;
  integer tests, errors;

  hazard_unit dut(
    .opD(opD),
    .Rs1D(Rs1D), .Rs2D(Rs2D),
    .Rs1E(Rs1E), .Rs2E(Rs2E),
    .RdE(RdE), .RdM(RdM), .RdW(RdW),
    .RegWriteE(RegWriteE), .RegWriteM(RegWriteM),
    .RegWriteW(RegWriteW),
    .ResultSrcE(ResultSrcE), .ResultSrcM(ResultSrcM),
    .PCSrcE(PCSrcE),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .StallF(StallF), .StallD(StallD),
    .FlushD(FlushD), .FlushE(FlushE)
  );

  // Compara las salidas con lo esperado
  task check;
    input [1:0] expectedA, expectedB;
    input expectedStallF, expectedStallD;
    input expectedFlushD, expectedFlushE;
    begin
      #1;
      tests = tests + 1;
      if ({ForwardAE, ForwardBE, StallF, StallD, FlushD, FlushE} !==
          {expectedA, expectedB, expectedStallF, expectedStallD,
           expectedFlushD, expectedFlushE}) begin
        errors = errors + 1;
        $display("Error en caso %0d: salidas = %b", tests,
                 {ForwardAE, ForwardBE, StallF, StallD, FlushD, FlushE});
      end
    end
  endtask

  initial begin
    tests = 0;
    errors = 0;
    opD = 7'b0110011;
    Rs1D = 1;
    Rs2D = 2;
    Rs1E = 3;
    Rs2E = 4;
    RdE = 5;
    RdM = 6;
    RdW = 7;
    RegWriteE = 0;
    RegWriteM = 0;
    RegWriteW = 0;
    ResultSrcE = 0;
    ResultSrcM = 0;
    PCSrcE = 0;

    // 1: Sin dependencias
    check(0, 0, 0, 0, 0, 0);

    // 2: MEM reenvia al operando A
    RegWriteM = 1;
    RdM = 3;
    check(2'b10, 0, 0, 0, 0, 0);

    // 3: MEM reenvia al operando B
    RdM = 4;
    check(0, 2'b10, 0, 0, 0, 0);

    // 4: WB reenvia al operando A
    RegWriteM = 0;
    RegWriteW = 1;
    RdW = 3;
    check(2'b01, 0, 0, 0, 0, 0);

    // 5: WB reenvia al operando B
    RdW = 4;
    check(0, 2'b01, 0, 0, 0, 0);

    // 6: Ambos operandos reciben de etapas distintas
    RegWriteM = 1;
    RdM = 3;
    check(2'b10, 2'b01, 0, 0, 0, 0);

    // 7: MEM gana si WB escribe el mismo registro
    RdW = 3;
    Rs2E = 3;
    check(2'b10, 2'b10, 0, 0, 0, 0);

    // 8: Una carga en MEM no reenvia su direccion
    ResultSrcM = 2'b01;
    check(0, 0, 0, 0, 0, 0);

    // 9: La carga en MEM bloquea un valor viejo de WB
    Rs1E = 4;
    RdW = 4;
    check(2'b01, 0, 0, 0, 0, 0);

    // 10: JAL permite reenviar su PC+4 desde MEM
    ResultSrcM = 2'b10;
    check(2'b01, 2'b10, 0, 0, 0, 0);

    // 11: Una carga en WB ya puede reenviar su dato
    RegWriteM = 0;
    Rs1E = 4;
    Rs2E = 4;
    check(2'b01, 2'b01, 0, 0, 0, 0);

    // 12: No se reenvian escrituras a x0
    RegWriteM = 1;
    RdM = 0;
    RdW = 0;
    Rs1E = 0;
    Rs2E = 0;
    ResultSrcM = 0;
    check(0, 0, 0, 0, 0, 0);

    // 13: RegWrite desactivado impide el forwarding
    Rs1E = 3;
    Rs2E = 3;
    RdM = 3;
    RdW = 3;
    RegWriteM = 0;
    RegWriteW = 0;
    check(0, 0, 0, 0, 0, 0);

    // 14: Load-Use por rs1
    RegWriteE = 1;
    ResultSrcE = 2'b01;
    RdE = 1;
    check(0, 0, 1, 1, 0, 1);

    // 15: Load-Use por rs2
    RdE = 2;
    check(0, 0, 1, 1, 0, 1);

    // 16: La pausa termina cuando la carga sale de EX
    RegWriteE = 0;
    check(0, 0, 0, 0, 0, 0);

    // 17: Un resultado ALU no causa Load-Use
    RegWriteE = 1;
    ResultSrcE = 0;
    check(0, 0, 0, 0, 0, 0);

    // 18: Una carga independiente no causa pausa
    ResultSrcE = 2'b01;
    RdE = 8;
    check(0, 0, 0, 0, 0, 0);

    // 19: Una carga a x0 no causa pausa
    RdE = 0;
    Rs1D = 0;
    Rs2D = 0;
    check(0, 0, 0, 0, 0, 0);

    // 20: ADDI no lee el campo rs2
    opD = 7'b0010011;
    Rs1D = 1;
    Rs2D = 2;
    RdE = 2;
    check(0, 0, 0, 0, 0, 0);

    // 21: ADDI si depende de rs1
    RdE = 1;
    check(0, 0, 1, 1, 0, 1);

    // 22: LW no lee el campo rs2
    opD = 7'b0000011;
    RdE = 2;
    check(0, 0, 0, 0, 0, 0);

    // 23: LW depende de su registro base
    RdE = 1;
    check(0, 0, 1, 1, 0, 1);

    // 24: SW depende del dato que va a escribir
    opD = 7'b0100011;
    RdE = 2;
    check(0, 0, 1, 1, 0, 1);

    // 25: SW depende de su registro base
    RdE = 1;
    check(0, 0, 1, 1, 0, 1);

    // 26: BEQ depende de rs1
    opD = 7'b1100011;
    check(0, 0, 1, 1, 0, 1);

    // 27: BEQ depende de rs2
    RdE = 2;
    check(0, 0, 1, 1, 0, 1);

    // 28: JAL no lee rs1 ni rs2
    opD = 7'b1101111;
    Rs1D = 2;
    check(0, 0, 0, 0, 0, 0);

    // 29: Una burbuja no causa pausa
    opD = 0;
    check(0, 0, 0, 0, 0, 0);

    // 30: Un salto tomado limpia Decode y Execute
    RegWriteE = 0;
    PCSrcE = 1;
    check(0, 0, 0, 0, 1, 1);

    // 31: El salto tiene prioridad si coinciden las condiciones
    opD = 7'b0110011;
    RegWriteE = 1;
    check(0, 0, 0, 0, 1, 1);

    // 32: Sin salto se mantiene la pausa Load-Use
    PCSrcE = 0;
    check(0, 0, 1, 1, 0, 1);

    // 33: Al desaparecer el hazard se liberan las etapas
    RegWriteE = 0;
    check(0, 0, 0, 0, 0, 0);

    if (errors == 0)
      $display("Hazard Unit: %0d casos correctos", tests);
    else
      $display("Hazard Unit: %0d errores en %0d casos", errors, tests);
    $finish;
  end
endmodule
