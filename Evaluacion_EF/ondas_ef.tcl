# Ondas para el informe final.
# Uso, en la Tcl Console de Vivado con la simulacion abierta:
#   source <ruta>/Evaluacion_EF/ondas_ef.tcl
#   ondas_profesor   (con tb_profesor abierto)
#   ondas_propio     (con tb_propio abierto)
# Cada comando crea las ventanas de ondas, corre la simulacion completa y
# guarda cada configuracion como ef_<nombre>.wcfg en esta carpeta
# (para reabrirla: File > Simulation Waveform > Open Configuration).
# Las ventanas de tiempo de cada figura estan en el README de esta carpeta.

set ::ondas_ef_dir [file dirname [file normalize [info script]]]

proc ef_add {radix base args} {
  foreach s $args {
    add_wave -radix $radix $base/$s
  }
}

# Cierre de etapas de una arquitectura: senal de comprobacion del testbench,
# registros y memoria que demuestran el resultado de cada etapa
proc ef_etapas {ev arq pre nombre regs basew nw} {
  set cfg [create_wave_config "EF cierre de etapas $nombre"]
  add_wave_divider "Reloj"
  add_wave $ev/clk
  add_wave_divider "Comprobacion del testbench (chk = 1 al cerrar una etapa)"
  add_wave $ev/${pre}_chk
  add_wave -radix unsigned $ev/${pre}_etapa
  add_wave -radix bin $ev/${pre}_ok
  add_wave_divider "Registros"
  foreach r $regs {
    add_wave -radix dec $ev/$arq/rv/dp/rf/rf\[$r\]
  }
  add_wave_divider "Memoria (palabra $basew = x1 + 0)"
  for {set w 0} {$w < $nw} {incr w} {
    add_wave -radix dec $ev/$arq/dmem/RAM\[[expr {$basew + $w}]\]
  }
  ef_pipe $ev $arq $nombre
  return $cfg
}

# Par en ID de una arquitectura Dual-Issue
proc ef_par {ev arq} {
  set dp $ev/$arq/rv/dp
  set c  $ev/$arq/rv/c
  add_wave_divider "Reloj"
  add_wave $ev/clk
  add_wave_divider "Par en ID ($arq)"
  ef_add unsigned $dp PCD
  ef_add hex $dp InstrD_0 InstrD_1
  ef_add bin $dp LoadPairD
  add_wave_divider "Issue Unit"
  ef_add bin $c Issue1D
  ef_add bin $c/issue RAW MemConflict BranchConflict
}

proc ef_wb {ev arq} {
  set dp $ev/$arq/rv/dp
  set c  $ev/$arq/rv/c
  add_wave_divider "Escritura en WB"
  ef_add bin $c RegWriteW_0
  ef_add unsigned $dp RdW_0
  ef_add dec $dp ResultW_0
  ef_add bin $c RegWriteW_1
  ef_add unsigned $dp RdW_1
  ef_add dec $dp ResultW_1
}

# Instruccion que hay en cada etapa del pipeline (00000000 = burbuja).
# Single-Issue: una por etapa. Dual-Issue: posicion 0 y 1 de cada etapa
proc ef_pipe {ev arq titulo} {
  set dp $ev/$arq/rv/dp
  add_wave_divider "Instruccion en cada etapa: $titulo (00000000 = burbuja)"
  if {$arq eq "single"} {
    ef_add unsigned $dp PCF
    ef_add hex $dp InstrF InstrD InstrE InstrM InstrW
  } else {
    ef_add unsigned $dp PCF
    ef_add hex $dp InstrF_0 InstrF_1
    ef_add unsigned $dp PCD
    ef_add hex $dp InstrD_0 InstrD_1 InstrE_0 InstrE_1 InstrM_0 InstrM_1 InstrW_0 InstrW_1
  }
}

proc ef_guardar {cfgs} {
  restart
  run all
  foreach {cfg nombre} $cfgs {
    save_wave_config -object $cfg [file join $::ondas_ef_dir ef_$nombre.wcfg]
    puts "Listo: ef_$nombre.wcfg"
  }
}

proc ondas_profesor {} {
  set ev /tb_profesor/ev
  set regs {5 6 10 12 15 18 21 22 24 28 29 31}
  set cfgs {}

  # 1. Cierre de etapas A, B, C y D en cada arquitectura
  lappend cfgs [ef_etapas $ev single a "A Pipeline" $regs 384 14] prof_etapas_pipeline
  lappend cfgs [ef_etapas $ev dual b "B Dual-Issue" $regs 384 14] prof_etapas_dual
  lappend cfgs [ef_etapas $ev opt c "C Optimizado" $regs 384 14] prof_etapas_opt

  # 2. Caso clave: doble emision y conflicto del puerto de memoria (etapa A)
  lappend cfgs [create_wave_config "EF doble emision y memoria"] prof_doble_memoria
  ef_par $ev dual
  add_wave_divider "Puerto de memoria (MemSelM = 1: lo usa la via 1)"
  ef_add bin $ev/dual/rv/c MemSelM MemWriteM
  ef_add unsigned $ev/dual/rv/dp DataAdrM
  ef_add dec $ev/dual/rv/dp WriteDataM
  ef_wb $ev dual
  ef_pipe $ev dual "B Dual-Issue"

  # 3. Caso clave: Load-Use, RAW y conflictos de memoria (etapa B)
  lappend cfgs [create_wave_config "EF Load-Use y RAW"] prof_loaduse
  ef_par $ev dual
  add_wave_divider "Hazard Unit"
  ef_add bin $ev/dual/rv/c StallD FlushE BlockIssue1D
  add_wave_divider "Forwarding (000 reg, 001 WB0, 010 WB1, 011 MEM0, 100 MEM1)"
  ef_add bin $ev/dual/rv/c ForwardAE_0 ForwardBE_0 ForwardAE_1 ForwardBE_1
  ef_wb $ev dual
  ef_pipe $ev dual "B Dual-Issue"

  # 4. Optimizacion: bucle C1 en el Dual-Issue (B) y con predictor (C)
  lappend cfgs [create_wave_config "EF predictor bucle C1"] prof_predictor
  add_wave_divider "Reloj"
  add_wave $ev/clk
  add_wave_divider "B: Dual-Issue (salto resuelto en EX, flush en cada vuelta)"
  ef_add unsigned $ev/dual/rv/dp PCF PCD
  ef_add bin $ev/dual/rv/c PCSrcE FlushD
  add_wave -radix dec $ev/dual/rv/dp/rf/rf\[19\]
  add_wave_divider "C: prediccion en IF"
  ef_add unsigned $ev/opt/rv/dp PCF PCD
  ef_add bin $ev/opt/rv/dp PredF_0 PredF_1
  ef_add unsigned $ev/opt/rv/dp PTgtF_0 PTgtF_1
  add_wave_divider "C: verificacion en EX (solo hay flush si la prediccion falla)"
  ef_add bin $ev/opt/rv/c CtrlE PCSrcE
  ef_add bin $ev/opt/rv/dp MisE_0 MisE_1 RedirectE
  ef_add unsigned $ev/opt/rv/dp CorrectPCE
  ef_add bin $ev/opt/rv/c FlushD
  add_wave -radix dec $ev/opt/rv/dp/rf/rf\[19\]
  ef_pipe $ev dual "B Dual-Issue"
  ef_pipe $ev opt "C Optimizado"

  ef_guardar $cfgs
}

proc ondas_propio {} {
  set ev /tb_propio/ev
  # suma, maximo, cantidad > 10, F(11), minimo y maximo ordenados
  set regs {8 9 10 16 22 23}
  set cfgs {}
  lappend cfgs [ef_etapas $ev single a "A Pipeline" $regs 256 13] propio_etapas_pipeline
  lappend cfgs [ef_etapas $ev dual b "B Dual-Issue" $regs 256 13] propio_etapas_dual
  lappend cfgs [ef_etapas $ev opt c "C Optimizado" $regs 256 13] propio_etapas_opt

  # Bucle interno del ordenamiento: Load-Use y saltos en B y en C
  lappend cfgs [create_wave_config "EF ordenamiento B y C"] propio_predictor
  add_wave_divider "Reloj"
  add_wave $ev/clk
  add_wave_divider "B: Dual-Issue"
  ef_add unsigned $ev/dual/rv/dp PCF PCD
  ef_add bin $ev/dual/rv/c StallD PCSrcE FlushD
  add_wave_divider "C: con predictor"
  ef_add unsigned $ev/opt/rv/dp PCF PCD
  ef_add bin $ev/opt/rv/dp PredF_0 PredF_1
  ef_add bin $ev/opt/rv/c StallD CtrlE PCSrcE
  ef_add bin $ev/opt/rv/dp MisE_0 MisE_1 RedirectE
  ef_add bin $ev/opt/rv/c FlushD
  ef_pipe $ev dual "B Dual-Issue"
  ef_pipe $ev opt "C Optimizado"

  ef_guardar $cfgs
}
