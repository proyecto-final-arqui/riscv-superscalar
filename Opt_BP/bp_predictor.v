// Predictor de saltos de 2 bits con Branch Target Buffer (BTB).
// Cada entrada guarda el tag del PC del salto, su destino y un contador
// saturado de 2 bits (00 y 01: no tomado, 10 y 11: tomado).
// Se consulta en IF con las dos direcciones del par y se actualiza en EX
// con el salto que se acaba de resolver.
module bp_predictor #(parameter IDX = 4) (
    input clk, reset,
    // Consulta en IF
    input [31:0] pc0, pc1,
    output pred0, pred1,
    output [31:0] tgt0, tgt1,
    // Actualizacion desde EX
    input upd_en, upd_taken,
    input [31:0] upd_pc, upd_target
);

  localparam N = 1 << IDX;
  localparam TW = 30 - IDX;          // bits del tag: PC[31:IDX+2]

  reg valid[0:N-1];
  reg [TW-1:0] tag[0:N-1];
  reg [31:0] target[0:N-1];
  reg [1:0] ctr[0:N-1];
  integer i;

  wire [IDX-1:0] i0 = pc0[IDX+1:2];
  wire [IDX-1:0] i1 = pc1[IDX+1:2];
  wire [IDX-1:0] iu = upd_pc[IDX+1:2];

  // Hay prediccion si la entrada es de ese mismo PC y el contador dice "tomado"
  wire hit0 = valid[i0] && (tag[i0] == pc0[31:IDX+2]);
  wire hit1 = valid[i1] && (tag[i1] == pc1[31:IDX+2]);
  assign pred0 = hit0 && ctr[i0][1];
  assign pred1 = hit1 && ctr[i1][1];
  assign tgt0 = target[i0];
  assign tgt1 = target[i1];

  wire hitu = valid[iu] && (tag[iu] == upd_pc[31:IDX+2]);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      for (i = 0; i < N; i = i + 1) begin
        valid[i] <= 0;
        tag[i] <= 0;
        target[i] <= 0;
        ctr[i] <= 2'b01;
      end
    end else if (upd_en) begin
      if (hitu) begin
        // Contador saturado: sube si se tomo, baja si no
        if (upd_taken && ctr[iu] != 2'b11)
          ctr[iu] <= ctr[iu] + 1;
        else if (!upd_taken && ctr[iu] != 2'b00)
          ctr[iu] <= ctr[iu] - 1;
      end else begin
        // Salto nuevo: se guarda su destino y empieza en "debilmente"
        // tomado o no tomado segun lo que acaba de hacer
        valid[iu] <= 1;
        tag[iu] <= upd_pc[31:IDX+2];
        ctr[iu] <= upd_taken ? 2'b10 : 2'b01;
      end
      target[iu] <= upd_target;
    end
  end
endmodule
