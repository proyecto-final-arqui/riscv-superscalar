# Ondas para el informe E2.
# Uso, en la Tcl Console de Vivado:
#   source C:/Users/joacm/Documents/vivado/SingleCycle_26II/project_1/Dual_E1/ondas_dual.tcl
#   ondas_dual     (con la simulacion de tb_dual abierta)
#   ondas_orden    (con la simulacion de tb_orden abierta)
# Cada comando crea las ventanas de ondas, corre la simulacion completa y
# guarda cada configuracion como e2_<nombre>.wcfg en esta misma carpeta
# (para reabrirla: File > Simulation Waveform > Open Configuration).
# En el informe se indica la ventana de tiempo de cada figura.

set ::ondas_dual_dir [file dirname [file normalize [info script]]]

# Agrega una lista de senales de un mismo bloque con el radix indicado
proc ondas_add {radix base args} {
  foreach s $args {
    add_wave -radix $radix $base/$s
  }
}

# Senales comunes: reloj y par de instrucciones en ID
proc ondas_par {tb p} {
  set dp $tb/$p/dual/rv/dp
  set c  $tb/$p/dual/rv/c
  add_wave_divider "Reloj"
  add_wave $tb/$p/clk
  add_wave_divider "Par en ID (00000000 = vacio)"
  ondas_add unsigned $dp PCD
  ondas_add hex $dp InstrD_0 InstrD_1
  ondas_add bin $dp ValidD LoadPairD
  add_wave_divider "Issue Unit"
  ondas_add bin $c Issue1D
}

proc ondas_dual {} {
  set tb /tb_dual
  set cfgs {}

  # Programa 5, 25-75 ns: emision doble, RAW dentro del par,
  # reagrupamiento, forwarding entre vias y dos escrituras en WB
  set dp $tb/p5/dual/rv/dp
  set c  $tb/p5/dual/rv/c
  lappend cfgs [create_wave_config "E2 emision (P5)"] emision
  ondas_par $tb p5
  add_wave_divider "Forwarding (000 reg, 001 WB0, 010 WB1, 011 MEM0, 100 MEM1)"
  ondas_add bin $c ForwardAE_0 ForwardBE_0 ForwardAE_1 ForwardBE_1
  add_wave_divider "Escritura via 0"
  ondas_add bin $c RegWriteW_0
  ondas_add unsigned $dp RdW_0
  ondas_add dec $dp ResultW_0
  add_wave_divider "Escritura via 1"
  ondas_add bin $c RegWriteW_1
  ondas_add unsigned $dp RdW_1
  ondas_add dec $dp ResultW_1

  # Programa 5, 85-125 ns: dos escrituras a x8 en el mismo par
  lappend cfgs [create_wave_config "E2 dos escrituras (P5)"] waw
  ondas_par $tb p5
  add_wave_divider "Forwarding de x8 hacia add x9 (100 = MEM via 1)"
  ondas_add bin $c ForwardAE_0 ForwardBE_0
  add_wave_divider "Escritura via 0"
  ondas_add bin $c RegWriteW_0
  ondas_add unsigned $dp RdW_0
  ondas_add dec $dp ResultW_0
  add_wave_divider "Escritura via 1"
  ondas_add bin $c RegWriteW_1
  ondas_add unsigned $dp RdW_1
  ondas_add dec $dp ResultW_1
  add_wave_divider "Banco de registros"
  add_wave -radix dec $dp/rf/rf\[8\]
  add_wave -radix dec $dp/rf/rf\[9\]

  # Programa 5, 255-295 ns: Load-Use de I1
  lappend cfgs [create_wave_config "E2 Load-Use de I1 (P5)"] loaduse1
  ondas_par $tb p5
  add_wave_divider "Hazard Unit"
  ondas_add bin $c BlockIssue1D StallD FlushE
  add_wave_divider "Forwarding (001 = WB via 0)"
  ondas_add bin $c ForwardAE_0 ForwardBE_0

  # Programa 6, 35-95 ns: memoria en ambas posiciones, Load-Use y
  # conflicto del puerto
  set dp $tb/p6/dual/rv/dp
  set c  $tb/p6/dual/rv/c
  lappend cfgs [create_wave_config "E2 memoria (P6)"] memoria
  ondas_par $tb p6
  add_wave_divider "Hazard Unit"
  ondas_add bin $c StallD FlushE
  ondas_add bin $c ForwardAE_0 ForwardBE_0
  add_wave_divider "Puerto de memoria (MemSelM = 1: lo usa la via 1)"
  ondas_add bin $c MemSelM MemWriteM
  ondas_add unsigned $dp DataAdrM
  ondas_add dec $dp WriteDataM ReadDataM

  # Programa 6, 95-215 ns: saltos en ambas posiciones y flushing
  lappend cfgs [create_wave_config "E2 saltos (P6)"] saltos
  ondas_par $tb p6
  add_wave_divider "Recurso de saltos (BranchSelE = 1: salto de la via 1)"
  ondas_add bin $c BranchSelE PCSrcE
  ondas_add unsigned $dp PCTargetE
  add_wave_divider "Flushing"
  ondas_add bin $c FlushD FlushE
  add_wave_divider "I1 anulada tras un salto de I0"
  ondas_add bin $c RegWriteM_1 RegWriteW_1
  ondas_add unsigned $dp RdW_1
  ondas_add dec $dp ResultW_1

  # Seis programas: mismo resultado y ciclos de cada arquitectura.
  # Leer los valores al final de la simulacion
  lappend cfgs [create_wave_config "E2 resultados (tb_dual)"] resultados
  foreach p {p1 p2 p3 p4 p5 p6} {
    add_wave_divider "Programa [string index $p 1]"
    ondas_add unsigned $tb/$p errors end_s end_d
  }

  restart
  run all

  foreach {cfg nombre} $cfgs {
    save_wave_config -object $cfg [file join $::ondas_dual_dir e2_$nombre.wcfg]
    puts "Listo: e2_$nombre.wcfg"
  }
}

proc ondas_orden {} {
  set tb /tb_orden
  set cfg [create_wave_config "E2 orden (tb_orden)"]
  # ns: instrucciones completadas en el Single, nd: en el Dual
  foreach p {p1 p2 p3 p4 p5 p6} {
    add_wave_divider "Programa [string index $p 1]"
    ondas_add unsigned $tb/$p ns nd errors
  }

  restart
  run all

  save_wave_config -object $cfg [file join $::ondas_dual_dir e2_orden.wcfg]
  puts "Listo: e2_orden.wcfg"
}
