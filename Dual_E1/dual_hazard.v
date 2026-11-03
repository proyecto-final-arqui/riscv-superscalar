module dual_hazard(
    input [6:0] opD,
    input [4:0] Rs1D, Rs2D,
    input [4:0] Rs1E_0, Rs2E_0, Rs1E_1, Rs2E_1,
    input [4:0] RdE_0, RdM_0, RdW_0, RdM_1, RdW_1,
    input RegWriteE_0, RegWriteM_0, RegWriteW_0,
    input RegWriteM_1, RegWriteW_1,
    input [1:0] ResultSrcE_0, ResultSrcM_0,
    input PCSrcE,
    output [2:0] ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1,
    output StallF, StallD,
    output FlushD, FlushE
);

  reg UseRs1D, UseRs2D;
  wire LoadUseStall;

  // Indica que registros lee la instruccion de la via 0
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

  // 000: registro, 001: WB via 0, 010: WB via 1, 011: MEM via 0, 100: MEM via 1.
  // Gana el productor mas joven: MEM antes que WB y, en la misma etapa,
  // la via 1 antes que la via 0. Una carga en MEM no se reenvia
  function [2:0] forward;
    input [4:0] rs;
    input RegWriteM_1, RegWriteM_0, RegWriteW_1, RegWriteW_0;
    input [4:0] RdM_1, RdM_0, RdW_1, RdW_0;
    input LoadM_0;
    begin
      if (rs == 0)
        forward = 3'b000;
      else if (RegWriteM_1 && (rs == RdM_1))
        forward = 3'b100;
      else if (RegWriteM_0 && (rs == RdM_0))
        forward = LoadM_0 ? 3'b000 : 3'b011;
      else if (RegWriteW_1 && (rs == RdW_1))
        forward = 3'b010;
      else if (RegWriteW_0 && (rs == RdW_0))
        forward = 3'b001;
      else
        forward = 3'b000;
    end
  endfunction

  // Todas las senales entran como argumentos para que el simulador
  // recalcule el forwarding cada vez que cambie alguna
  wire LoadM_0 = (ResultSrcM_0 == 2'b01);

  assign ForwardAE_0 = forward(Rs1E_0, RegWriteM_1, RegWriteM_0, RegWriteW_1,
                               RegWriteW_0, RdM_1, RdM_0, RdW_1, RdW_0, LoadM_0);
  assign ForwardBE_0 = forward(Rs2E_0, RegWriteM_1, RegWriteM_0, RegWriteW_1,
                               RegWriteW_0, RdM_1, RdM_0, RdW_1, RdW_0, LoadM_0);
  assign ForwardAE_1 = forward(Rs1E_1, RegWriteM_1, RegWriteM_0, RegWriteW_1,
                               RegWriteW_0, RdM_1, RdM_0, RdW_1, RdW_0, LoadM_0);
  assign ForwardBE_1 = forward(Rs2E_1, RegWriteM_1, RegWriteM_0, RegWriteW_1,
                               RegWriteW_0, RdM_1, RdM_0, RdW_1, RdW_0, LoadM_0);

  // Detecta una carga cuyo dato aun no esta listo (solo la via 0 hace lw)
  assign LoadUseStall = RegWriteE_0 && (ResultSrcE_0 == 2'b01) &&
                        (RdE_0 != 0) &&
                        ((UseRs1D && (Rs1D == RdE_0)) ||
                         (UseRs2D && (Rs2D == RdE_0)));

  // Un salto tomado tiene prioridad sobre la pausa
  assign StallF = LoadUseStall && !PCSrcE;
  assign StallD = LoadUseStall && !PCSrcE;
  assign FlushD = PCSrcE;
  assign FlushE = LoadUseStall || PCSrcE;
endmodule
