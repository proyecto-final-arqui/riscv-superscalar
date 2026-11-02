module hazard_unit(
    input [6:0] opD,
    input [4:0] Rs1D, Rs2D,
    input [4:0] Rs1E, Rs2E,
    input [4:0] RdE, RdM, RdW,
    input RegWriteE, RegWriteM, RegWriteW,
    input [1:0] ResultSrcE, ResultSrcM,
    input PCSrcE,
    output reg [1:0] ForwardAE, ForwardBE,
    output StallF, StallD,
    output FlushD, FlushE
);

  reg UseRs1D, UseRs2D;
  wire LoadUseStall;

  // Indica que registros lee la instruccion
  always @* begin
    UseRs1D = 0;
    UseRs2D = 0;

    case (opD)
      7'b0110011, 7'b0100011, 7'b1100011: begin
        UseRs1D = 1;
        UseRs2D = 1;
      end
      7'b0000011, 7'b0010011: begin
        UseRs1D = 1;
        UseRs2D = 0;
      end
      default: begin
        UseRs1D = 0;
        UseRs2D = 0;
      end
    endcase
  end

  // 00: registro, 10: MEM, 01: WB
  always @* begin
    ForwardAE = 2'b00;
    ForwardBE = 2'b00;

    // MEM tiene prioridad sobre WB
    if ((Rs1E != 0) && RegWriteM && (Rs1E == RdM)) begin
      if (ResultSrcM != 2'b01)
        ForwardAE = 2'b10;
    end else if ((Rs1E != 0) && RegWriteW && (Rs1E == RdW)) begin
      ForwardAE = 2'b01;
    end

    if ((Rs2E != 0) && RegWriteM && (Rs2E == RdM)) begin
      if (ResultSrcM != 2'b01)
        ForwardBE = 2'b10;
    end else if ((Rs2E != 0) && RegWriteW && (Rs2E == RdW)) begin
      ForwardBE = 2'b01;
    end
  end

  // Detecta una carga cuyo dato aun no esta listo
  assign LoadUseStall = RegWriteE && (ResultSrcE == 2'b01) &&
                        (RdE != 0) &&
                        ((UseRs1D && (Rs1D == RdE)) ||
                         (UseRs2D && (Rs2D == RdE)));

  // Un salto tomado tiene prioridad sobre la pausa
  assign StallF = LoadUseStall && !PCSrcE;
  assign StallD = LoadUseStall && !PCSrcE;
  assign FlushD = PCSrcE;
  assign FlushE = LoadUseStall || PCSrcE;
endmodule
