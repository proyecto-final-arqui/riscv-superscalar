#!/bin/bash
# Corre la evaluacion de la entrega final con Icarus Verilog.
# Uso, desde Ubuntu (WSL) en la carpeta Evaluacion_EF:
#   bash correr_icarus.sh            -> programa del profesor y programa propio
#   bash correr_icarus.sh profesor   -> solo uno (profesor o propio)
# Deja los resultados en sim/ y las ondas en sim/tb_<programa>.vcd
set -e
cd "$(dirname "$0")"
R=..
mkdir -p sim
cp *.mem $R/Pipeline_E1/*.mem sim/
SRC="$R/Pipeline_E1/alu.v $R/Pipeline_E1/aludec.v $R/Pipeline_E1/controller_pipeline.v \
     $R/Pipeline_E1/datapath_pipeline.v $R/Pipeline_E1/dmem.v $R/Pipeline_E1/extend.v \
     $R/Pipeline_E1/hazard_unit.v $R/Pipeline_E1/imem.v $R/Pipeline_E1/maindec.v \
     $R/Pipeline_E1/regfile.v $R/Pipeline_E1/riscv_pipeline.v $R/Pipeline_E1/top_pipeline.v \
     $R/Dual_E1/dual_datapath.v $R/Dual_E1/dual_decode.v $R/Dual_E1/dual_fetch.v \
     $R/Dual_E1/dual_hazard.v $R/Dual_E1/dual_issue.v $R/Dual_E1/dual_regfile.v \
     $R/Dual_E1/dual_riscv.v $R/Dual_E1/dual_top.v \
     $R/Opt_BP/bp_predictor.v $R/Opt_BP/bp_datapath.v $R/Opt_BP/bp_decode.v \
     $R/Opt_BP/bp_riscv.v $R/Opt_BP/bp_top.v tb_evaluacion.v"
for p in ${1:-profesor propio}; do
  iverilog -g2005 -DVCD -o sim/tb_$p.vvp -s tb_$p $SRC
  (cd sim && vvp -n tb_$p.vvp | grep -v "readmemh")
done
