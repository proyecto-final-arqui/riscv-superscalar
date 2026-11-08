`timescale 1ns/1ps

module tb_dual_hazard;
  reg [6:0] opD_0, opD_1;
  reg [4:0] Rs1D_0, Rs2D_0, Rs1D_1, Rs2D_1, Rs1E_0, Rs2E_0, Rs1E_1, Rs2E_1, RdE_0, RdE_1, RdM_0, RdM_1, RdW_0, RdW_1;
  reg  RegWriteE_0, RegWriteE_1, RegWriteM_0, RegWriteM_1, RegWriteW_0, RegWriteW_1, PCSrcE;
  reg [1:0] ResultSrcE_0, ResultSrcE_1, ResultSrcM_0, ResultSrcM_1;
  wire [2:0] ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1;
  wire StallF, StallD, BlockIssue1D, FlushD, FlushE;
  integer checks = 0;
  integer errors = 0;
  integer source, producer, consumer, operand, kind;
  reg [11:0] expected;
  reg [2:0] select;

  dual_hazard dut(
    .opD_0(opD_0),
    .opD_1(opD_1),
    .Rs1D_0(Rs1D_0),
    .Rs2D_0(Rs2D_0),
    .Rs1D_1(Rs1D_1),
    .Rs2D_1(Rs2D_1),
    .Rs1E_0(Rs1E_0),
    .Rs2E_0(Rs2E_0),
    .Rs1E_1(Rs1E_1),
    .Rs2E_1(Rs2E_1),
    .RdE_0(RdE_0),
    .RdE_1(RdE_1),
    .RdM_0(RdM_0),
    .RdM_1(RdM_1),
    .RdW_0(RdW_0),
    .RdW_1(RdW_1),
    .RegWriteE_0(RegWriteE_0),
    .RegWriteE_1(RegWriteE_1),
    .RegWriteM_0(RegWriteM_0),
    .RegWriteM_1(RegWriteM_1),
    .RegWriteW_0(RegWriteW_0),
    .RegWriteW_1(RegWriteW_1),
    .PCSrcE(PCSrcE),
    .ResultSrcE_0(ResultSrcE_0),
    .ResultSrcE_1(ResultSrcE_1),
    .ResultSrcM_0(ResultSrcM_0),
    .ResultSrcM_1(ResultSrcM_1),
    .ForwardAE_0(ForwardAE_0),
    .ForwardBE_0(ForwardBE_0),
    .ForwardAE_1(ForwardAE_1),
    .ForwardBE_1(ForwardBE_1),
    .StallF(StallF),
    .StallD(StallD),
    .BlockIssue1D(BlockIssue1D),
    .FlushD(FlushD),
    .FlushE(FlushE)
  );

  task clear_inputs;
    begin
      opD_0 = 0;
      opD_1 = 0;
      Rs1D_0 = 0;
      Rs2D_0 = 0;
      Rs1D_1 = 0;
      Rs2D_1 = 0;
      Rs1E_0 = 0;
      Rs2E_0 = 0;
      Rs1E_1 = 0;
      Rs2E_1 = 0;
      RdE_0 = 0;
      RdE_1 = 0;
      RdM_0 = 0;
      RdM_1 = 0;
      RdW_0 = 0;
      RdW_1 = 0;
      RegWriteE_0 = 0;
      RegWriteE_1 = 0;
      RegWriteM_0 = 0;
      RegWriteM_1 = 0;
      RegWriteW_0 = 0;
      RegWriteW_1 = 0;
      PCSrcE = 0;
      ResultSrcE_0 = 0;
      ResultSrcE_1 = 0;
      ResultSrcM_0 = 0;
      ResultSrcM_1 = 0;
    end
  endtask

  task check_forward;
    input [11:0] wanted;
    begin
      #1;
      checks = checks + 1;
      if ({ForwardBE_1, ForwardAE_1, ForwardBE_0, ForwardAE_0} !== wanted) begin
        errors = errors + 1;
        $display("Forwarding incorrecto, caso %0d: esperado %h, recibido %h",
          checks, wanted, {ForwardBE_1, ForwardAE_1, ForwardBE_0, ForwardAE_0});
      end
    end
  endtask

  task check_control;
    input [4:0] wanted;
    begin
      #1;
      checks = checks + 1;
      if ({StallF, StallD, BlockIssue1D, FlushD, FlushE} !== wanted) begin
        errors = errors + 1;
        $display("Control incorrecto, caso %0d: esperado %b, recibido %b",
          checks, wanted, {StallF, StallD, BlockIssue1D, FlushD, FlushE});
      end
    end
  endtask

  initial begin
    clear_inputs;
    check_forward(0);
    check_control(0);

    // Cada productor hacia los cuatro operandos de EX
    for (source = 0; source < 4; source = source + 1) begin
      for (producer = 0; producer < 4; producer = producer + 1) begin
        clear_inputs;
        case (source)
          0: Rs1E_0 = 5;
          1: Rs2E_0 = 5;
          2: Rs1E_1 = 5;
          3: Rs2E_1 = 5;
        endcase
        case (producer)
          0: begin RegWriteW_0 = 1; RdW_0 = 5; select = 1; end
          1: begin RegWriteW_1 = 1; RdW_1 = 5; select = 2; end
          2: begin RegWriteM_0 = 1; RdM_0 = 5; select = 3; end
          3: begin RegWriteM_1 = 1; RdM_1 = 5; select = 4; end
        endcase
        expected = 0;
        case (source)
          0: expected[2:0] = select;
          1: expected[5:3] = select;
          2: expected[8:6] = select;
          3: expected[11:9] = select;
        endcase
        check_forward(expected);
      end
    end

    // Prioridad, cargas en MEM y productores deshabilitados
    clear_inputs;
    Rs1E_0 = 5; Rs2E_0 = 5; Rs1E_1 = 5; Rs2E_1 = 5;
    RdM_0 = 5; RdM_1 = 5; RdW_0 = 5; RdW_1 = 5;
    RegWriteM_0 = 1; RegWriteM_1 = 1; RegWriteW_0 = 1; RegWriteW_1 = 1;
    check_forward({4{3'b100}});
    ResultSrcM_1 = 1;
    check_forward(0);
    RegWriteM_1 = 0;
    check_forward({4{3'b011}});
    ResultSrcM_0 = 1;
    check_forward(0);
    RegWriteM_0 = 0;
    check_forward({4{3'b010}});
    RegWriteW_1 = 0;
    check_forward({4{3'b001}});
    RegWriteW_0 = 0;
    check_forward(0);

    // Una ALU joven supera a una carga antigua al mismo destino
    RegWriteM_0 = 1; RegWriteM_1 = 1;
    ResultSrcM_1 = 0;
    check_forward({4{3'b100}});
    ResultSrcM_1 = 2;
    check_forward({4{3'b100}});

    // x0 nunca recibe forwarding
    Rs1E_0 = 0; Rs2E_0 = 0; Rs1E_1 = 0; Rs2E_1 = 0;
    RdM_0 = 0; RdM_1 = 0;
    check_forward(0);

    // Carga en cualquiera de las vias y consumidor en cualquiera
    for (producer = 0; producer < 2; producer = producer + 1) begin
      for (consumer = 0; consumer < 2; consumer = consumer + 1) begin
        for (operand = 0; operand < 2; operand = operand + 1) begin
          clear_inputs;
          opD_0 = 7'b0110011; opD_1 = 7'b0110011;
          if (producer == 0) begin
            RegWriteE_0 = 1; ResultSrcE_0 = 1; RdE_0 = 5;
          end else begin
            RegWriteE_1 = 1; ResultSrcE_1 = 1; RdE_1 = 5;
          end
          if (consumer == 0) begin
            if (operand == 0) Rs1D_0 = 5; else Rs2D_0 = 5;
            check_control(5'b11001);
          end else begin
            if (operand == 0) Rs1D_1 = 5; else Rs2D_1 = 5;
            check_control(5'b00100);
          end
        end
      end
    end

    // Ambos consumidores esperan; el salto tiene prioridad
    Rs1D_0 = 5;
    check_control(5'b11101);
    PCSrcE = 1;
    check_control(5'b00011);
    clear_inputs;
    PCSrcE = 1;
    check_control(5'b00011);

    // No hay pausa por x0 ni por una escritura deshabilitada
    clear_inputs;
    opD_0 = 7'b0110011; opD_1 = 7'b0110011;
    RegWriteE_0 = 1; RegWriteE_1 = 1;
    ResultSrcE_0 = 1; ResultSrcE_1 = 1;
    check_control(0);
    RdE_0 = 5; RdE_1 = 5; Rs1D_0 = 5; Rs1D_1 = 5;
    RegWriteE_0 = 0; RegWriteE_1 = 0;
    check_control(0);

    // La escritura mas joven en EX define si hay que esperar
    RegWriteE_0 = 1; RegWriteE_1 = 1;
    ResultSrcE_1 = 0;
    check_control(0);
    ResultSrcE_0 = 0; ResultSrcE_1 = 1;
    check_control(5'b11101);

    // Inmediatos, JAL, stores, branches y cargas en Decode
    for (consumer = 0; consumer < 2; consumer = consumer + 1) begin
      for (kind = 0; kind < 6; kind = kind + 1) begin
        clear_inputs;
        RegWriteE_1 = 1; ResultSrcE_1 = 1; RdE_1 = 5;
        if (consumer == 0) Rs2D_0 = 5; else Rs2D_1 = 5;
        case (kind)
          0: opD_0 = 7'b0010011;
          1: opD_0 = 7'b1101111;
          2: opD_0 = 7'b0100011;
          3: opD_0 = 7'b1100011;
          4: opD_0 = 7'b0000011;
          5: opD_0 = 0;
        endcase
        if (consumer == 1) begin opD_1 = opD_0; opD_0 = 0; end
        if (kind == 2 || kind == 3)
          check_control(consumer == 0 ? 5'b11001 : 5'b00100);
        else
          check_control(0);
        if (consumer == 0) Rs1D_0 = 5; else Rs1D_1 = 5;
        if (kind == 1 || kind == 5)
          check_control(0);
        else
          check_control(consumer == 0 ? 5'b11001 : 5'b00100);
      end
    end

    if (errors != 0) $fatal(1, "HAZARD DUAL: %0d errores", errors);
    $display("HAZARD DUAL: CORRECTO, %0d comprobaciones", checks);
    $finish;
  end
endmodule
