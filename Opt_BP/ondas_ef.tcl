# Script de ondas para Entrega Final (EF) en Vivado XSim.
# Uso en la Tcl Console de Vivado (con Behavioral Simulation abierta sobre tb_ef):
#   source [file join [get_property DIRECTORY [current_project]] Opt_BP ondas_ef.tcl]
#   ondas_ef cierre_abcd
#   ondas_ef cierre_a
#   ondas_ef cierre_b
#   ondas_ef cierre_c
#   ondas_ef cierre_d
#   ondas_ef caso_raw
#   ondas_ef caso_mem
#   ondas_ef caso_btb
#   ondas_ef prog8_btb

set ::ondas_ef_dir [file dirname [file normalize [info script]]]

proc ondas_ef {{vista cierre_abcd}} {
  set validas {cierre_abcd cierre_a cierre_b cierre_c cierre_d caso_raw caso_mem caso_btb prog8_btb}
  if {$vista ni $validas} {
    error "Vista desconocida '$vista'. Opciones: $validas"
  }

  if {$vista eq "prog8_btb"} {
    set tb /tb_ef/u_p8
  } else {
    set tb /tb_ef/u_prof
  }
  set dp $tb/bp/rv/dp
  set c  $tb/bp/rv/c

  if {[llength [get_objects -quiet $tb/clk]] == 0} {
    error "Abre primero Run Behavioral Simulation con tb_ef como Simulation Top."
  }

  set cfg [create_wave_config "EF - $vista"]

  add_wave_divider "Reloj"
  add_wave $tb/clk $tb/reset

  add_wave_divider "Fetch / Decode (C: Dual+BTB)"
  add_wave -radix hex $dp/PCF $dp/PCD $dp/PCD_1 $dp/InstrD_0 $dp/InstrD_1
  add_wave $c/Issue1D $dp/LoadPairD

  if {$vista in {cierre_abcd cierre_a cierre_b cierre_c cierre_d}} {
    add_wave_divider "Comprobacion de etapas (A-D)"
    add_wave $tb/chk_A_ok_p $tb/chk_B_ok_p $tb/chk_C_ok_p $tb/chk_D_ok_p
    add_wave $tb/chk_A_ok_d $tb/chk_B_ok_d $tb/chk_C_ok_d $tb/chk_D_ok_d
    add_wave $tb/chk_A_ok_s $tb/chk_B_ok_s $tb/chk_C_ok_s $tb/chk_D_ok_s
  }

  if {$vista in {caso_raw caso_mem}} {
    add_wave_divider "Hazards y Forwarding"
    add_wave $c/StallF $c/StallD $c/FlushD $c/FlushE $c/BlockIssue1D
    add_wave -radix bin $c/ForwardAE_0 $c/ForwardBE_0 $c/ForwardAE_1 $c/ForwardBE_1
  }

  if {$vista in {caso_btb prog8_btb cierre_c cierre_d}} {
    add_wave_divider "Predictor BTB 2-bits"
    add_wave $dp/PredF_0 $dp/PredF_1 $dp/PredD_0 $dp/PredD_1 $dp/PredE_0 $dp/PredE_1
    add_wave $c/CtrlE $c/PCSrcE $dp/MisE_0 $dp/MisE_1 $dp/RedirectE
    add_wave -radix hex $dp/PCTargetE $dp/CorrectPCE
  }

  add_wave_divider "Escritura en registros"
  add_wave $c/RegWriteW_0
  add_wave -radix unsigned $dp/RdW_0
  add_wave -radix dec $dp/ResultW_0
  add_wave $c/RegWriteW_1
  add_wave -radix unsigned $dp/RdW_1
  add_wave -radix dec $dp/ResultW_1

  add_wave_divider "Memoria de datos"
  add_wave $c/MemWriteM $c/MemSelM
  add_wave -radix unsigned $dp/DataAdrM
  add_wave -radix dec $dp/WriteDataM $dp/ReadDataM

  if {$vista eq "cierre_a"} {
    add_wave_divider "Registros clave Etapa A"
    foreach r {1 5 6 7 8 9 10} {
      add_wave -radix dec [format {%s/rf/rf[%d]} $dp $r]
    }
  } elseif {$vista eq "cierre_b"} {
    add_wave_divider "Registros clave Etapa B"
    foreach r {11 12 13 14 15 16 17 18} {
      add_wave -radix dec [format {%s/rf/rf[%d]} $dp $r]
    }
  } elseif {$vista eq "cierre_c"} {
    add_wave_divider "Registros clave Etapa C"
    foreach r {19 20 21 22 24 26} {
      add_wave -radix dec [format {%s/rf/rf[%d]} $dp $r]
    }
  } elseif {$vista eq "cierre_d"} {
    add_wave_divider "Registros clave Etapa D"
    foreach r {25 26 27 28 29 30 31} {
      add_wave -radix dec [format {%s/rf/rf[%d]} $dp $r]
    }
  }

  restart
  log_wave -r $tb
  run all

  set carpeta [file join $::ondas_ef_dir Ondas]
  file mkdir $carpeta
  set archivo [file join $carpeta ef_${vista}.wcfg]
  save_wave_config $archivo

  set inicio 0
  set fin 3000
  switch $vista {
    cierre_abcd {set inicio 0;    set fin 4700}
    cierre_a    {set inicio 90;   set fin 160}
    cierre_b    {set inicio 160;  set fin 290}
    cierre_c    {set inicio 2170; set fin 2250}
    cierre_d    {set inicio 2890; set fin 2970}
    caso_raw    {set inicio 20;   set fin 140}
    caso_mem    {set inicio 105;  set fin 245}
    caso_btb    {set inicio 270;  set fin 480}
    prog8_btb   {set inicio 2200; set fin 3300}
  }

  close_wave_config $cfg
  set f [open $archivo r]
  set xml [read $f]
  close $f

  set zoom "<zoom_setting><ZoomStartTime time=\"${inicio}000 ps\"/><ZoomEndTime time=\"${fin}000 ps\"/><Cursor1Time time=\"${inicio}000 ps\"/></zoom_setting>"
  if {![regsub {<zoom_setting>.*?</zoom_setting>} $xml $zoom xml]} {
    regsub {<wave_config>} $xml "<wave_config>\n$zoom" xml
  }
  set columnas {<column_width_setting><NameColumnWidth column_width="195"/><ValueColumnWidth column_width="90"/></column_width_setting>}
  if {![regsub {<column_width_setting>.*?</column_width_setting>} $xml $columnas xml]} {
    regsub {<wave_config>} $xml "<wave_config>\n$columnas" xml
  }

  set f [open $archivo w]
  puts $f $xml
  close $f
  open_wave_config $archivo
  puts "Listo: vista $vista guardada en $archivo (zoom ${inicio}..${fin} ns)"
}
