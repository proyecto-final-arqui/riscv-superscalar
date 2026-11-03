# Ondas para el informe E1.
# Uso, en la Tcl Console de Vivado con la simulación del programa N abierta:
#   source C:/Users/joacm/Documents/vivado/SingleCycle_26II/project_1/Pipeline_E1/ondas.tcl
#   ondas 2
# Crea una ventana de ondas nueva con las señales del programa, corre la
# simulación completa y guarda la configuración como ondas_programN.wcfg
# en esta misma carpeta (para reabrirla: File > Simulation Waveform > Open Configuration).

set ::ondas_dir [file dirname [file normalize [info script]]]

proc ondas {n} {
  set tb /testbench_program$n
  set dp $tb/dut/rv/dp
  set c  $tb/dut/rv/c

  create_wave_config "Programa $n"

  add_wave_divider "Reloj"
  add_wave $tb/clk $tb/reset

  add_wave_divider "Instruccion en cada etapa (00000000 = burbuja)"
  add_wave -radix hex $dp/PCF $dp/InstrF $dp/InstrD $dp/InstrE $dp/InstrM $dp/InstrW

  add_wave_divider "Hazard Unit"
  add_wave $c/StallF $c/StallD $c/FlushD $c/FlushE
  add_wave -radix bin $c/ForwardAE $c/ForwardBE

  # Señales propias de cada programa
  if {$n == 2} {
    add_wave_divider "Operandos que entran a la ALU (ya con forwarding)"
    add_wave -radix dec $dp/SrcAE $dp/WriteDataE
  } elseif {$n == 3} {
    add_wave_divider "Registro que carga la instruccion en EX"
    add_wave -radix unsigned $dp/RdE
  } elseif {$n == 4} {
    add_wave_divider "Salto"
    add_wave $c/PCSrcE
    add_wave -radix hex $dp/PCTargetE
  }

  add_wave_divider "Escritura en registros"
  add_wave $c/RegWriteW
  add_wave -radix unsigned $dp/RdW
  add_wave -radix dec $dp/ResultW

  add_wave_divider "Memoria de datos"
  add_wave $c/MemWriteM
  add_wave -radix dec $dp/ALUResultM $dp/WriteDataM

  restart
  run all

  save_wave_config [file join $::ondas_dir ondas_program$n.wcfg]
  puts "Listo: ondas_program$n.wcfg guardado en $::ondas_dir"
}
