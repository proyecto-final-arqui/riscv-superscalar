module dual_hazard(
    input [6:0] opD_0, opD_1,
    input [4:0] Rs1D_0, Rs2D_0, Rs1D_1, Rs2D_1,
    input [4:0] Rs1E_0, Rs2E_0, Rs1E_1, Rs2E_1,
    input [4:0] RdE_0, RdE_1, RdM_0, RdM_1, RdW_0, RdW_1,
    input RegWriteE_0, RegWriteE_1,
    input RegWriteM_0, RegWriteM_1, RegWriteW_0, RegWriteW_1,
    input [1:0] ResultSrcE_0, ResultSrcE_1, ResultSrcM_0, ResultSrcM_1,
    input PCSrcE,
    output [2:0] ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1,
    output StallF, StallD, BlockIssue1D,
    output FlushD, FlushE
);

  reg UseRs1D_0, UseRs2D_0, UseRs1D_1, UseRs2D_1;
  wire LoadUse0, LoadUse1;
  wire LoadE_0, LoadE_1, LoadM_0, LoadM_1;

  // Evita dependencias falsas con campos que son parte del inmediato
  always @* begin
    UseRs1D_0 = 0;
    UseRs2D_0 = 0;
    UseRs1D_1 = 0;
    UseRs2D_1 = 0;

    case (opD_0)
      7'b0110011, 7'b0100011, 7'b1100011: begin
        UseRs1D_0 = 1;
        UseRs2D_0 = 1;
      end
      7'b0000011, 7'b0010011: UseRs1D_0 = 1;
      default: begin end
    endcase

    case (opD_1)
      7'b0110011, 7'b0100011, 7'b1100011: begin
        UseRs1D_1 = 1;
        UseRs2D_1 = 1;
      end
      7'b0000011, 7'b0010011: UseRs1D_1 = 1;
      default: begin end
    endcase
  end

  assign LoadE_0 = (ResultSrcE_0 == 2'b01);
  assign LoadE_1 = (ResultSrcE_1 == 2'b01);
  assign LoadM_0 = (ResultSrcM_0 == 2'b01);
  assign LoadM_1 = (ResultSrcM_1 == 2'b01);

  // Elige el resultado mas reciente: MEM1, MEM0, WB1 y WB0
  function [2:0] forward;
    input [4:0] rs;
    input RegWriteM_1, RegWriteM_0, RegWriteW_1, RegWriteW_0;
    input [4:0] RdM_1, RdM_0, RdW_1, RdW_0;
    input LoadM_0, LoadM_1;
    begin
      if (rs == 0)
        forward = 3'b000;
      // Una carga pendiente impide usar un resultado mas antiguo
      else if (RegWriteM_1 && (rs == RdM_1))
        forward = LoadM_1 ? 3'b000 : 3'b100;
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

  // Busca el dato para los dos operandos de cada via
  assign ForwardAE_0 = forward(Rs1E_0, RegWriteM_1, RegWriteM_0, RegWriteW_1,
                               RegWriteW_0, RdM_1, RdM_0, RdW_1, RdW_0, LoadM_0, LoadM_1);
  assign ForwardBE_0 = forward(Rs2E_0, RegWriteM_1, RegWriteM_0, RegWriteW_1,
                               RegWriteW_0, RdM_1, RdM_0, RdW_1, RdW_0, LoadM_0, LoadM_1);
  assign ForwardAE_1 = forward(Rs1E_1, RegWriteM_1, RegWriteM_0, RegWriteW_1,
                               RegWriteW_0, RdM_1, RdM_0, RdW_1, RdW_0, LoadM_0, LoadM_1);
  assign ForwardBE_1 = forward(Rs2E_1, RegWriteM_1, RegWriteM_0, RegWriteW_1,
                               RegWriteW_0, RdM_1, RdM_0, RdW_1, RdW_0, LoadM_0, LoadM_1);

  // Espera si la ultima instruccion que escribe ese registro es un lw en EX
  function load_use;
    input [4:0] rs;
    input RegWriteE_0, RegWriteE_1;
    input [4:0] RdE_0, RdE_1;
    input LoadE_0, LoadE_1;
    begin
      if (rs == 0)
        load_use = 0;
      else if (RegWriteE_1 && (rs == RdE_1))
        load_use = LoadE_1;
      else if (RegWriteE_0 && (rs == RdE_0))
        load_use = LoadE_0;
      else
        load_use = 0;
    end
  endfunction

  // Revisa solo los registros que cada instruccion necesita
  assign LoadUse0 =
      (UseRs1D_0 && load_use(Rs1D_0, RegWriteE_0, RegWriteE_1, RdE_0, RdE_1, LoadE_0, LoadE_1)) ||
      (UseRs2D_0 && load_use(Rs2D_0, RegWriteE_0, RegWriteE_1, RdE_0, RdE_1, LoadE_0, LoadE_1));
  assign LoadUse1 =
      (UseRs1D_1 && load_use(Rs1D_1, RegWriteE_0, RegWriteE_1, RdE_0, RdE_1, LoadE_0, LoadE_1)) ||
      (UseRs2D_1 && load_use(Rs2D_1, RegWriteE_0, RegWriteE_1, RdE_0, RdE_1, LoadE_0, LoadE_1));

  // Si espera I0 se detiene el par; si espera I1 puede avanzar I0
  assign StallF = LoadUse0 && !PCSrcE;
  assign StallD = LoadUse0 && !PCSrcE;
  assign BlockIssue1D = LoadUse1 && !PCSrcE;
  assign FlushD = PCSrcE;
  assign FlushE = LoadUse0 || PCSrcE;
endmodule
