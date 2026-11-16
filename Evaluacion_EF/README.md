# Evaluación de la entrega final

Programas de comparación de las tres arquitecturas:
- **(A)** Pipeline Single-Issue: `Pipeline_E1`
- **(B)** Dual-Issue: `Dual_E1`
- **(C)** Dual-Issue con predictor de 2 bits y BTB: `Opt_BP`

## Cómo correrlo (resumen)

1. Abrir `project_1.xpr` en Vivado.
2. En **Simulation Sources → sim_1**, clic derecho sobre `tb_profesor` (o `tb_propio`) → **Set as Top**.
3. **Run Simulation → Run Behavioral Simulation**. En la Tcl Console aparece la comprobación de las etapas, la tabla de rendimiento y `RESULTADO: CORRECTO en las tres arquitecturas`.
4. Para las ondas, en la Tcl Console:
   ```
   source [get_property DIRECTORY [current_project]]/Evaluacion_EF/ondas_ef.tcl
   ondas_profesor
   ```
   (`ondas_propio` si la simulación abierta es `tb_propio`). En la sección "Waveforms en Vivado" están las ventanas de tiempo de cada figura.

Sin Vivado: `bash correr_icarus.sh` desde Ubuntu (WSL) con Icarus instalado. Ver la sección "Simulación".

## Archivos

| Archivo | Contenido |
| --- | --- |
| `profesor.s` | Programa del profesor, sin modificaciones (etapas A a D). |
| `propio.s` | Programa propio: procesamiento de un arreglo en cuatro etapas. |
| `*.mem` | Programas ensamblados. |
| `*_esperado.mem` | Estado esperado al final de cada etapa: 32 registros y 64 palabras de memoria desde la base de datos. |
| `rvasm.py` | Ensamblador y modelo de referencia. Genera los `.mem` y los estados esperados. |
| `tb_evaluacion.v` | Módulo `evaluar` y los tops `tb_profesor` y `tb_propio`. |
| `ondas_ef.tcl` | Crea las ventanas de ondas de las figuras del informe y las guarda como `ef_*.wcfg`. |
| `correr_icarus.sh` | Corre `tb_profesor` y `tb_propio` con Icarus Verilog y guarda las ondas en `sim/`. |

Para regenerar los archivos después de cambiar un programa:

```
python rvasm.py profesor.s etapa_A etapa_B etapa_C etapa_D fin
python rvasm.py propio.s etapa_1 etapa_2 etapa_3 etapa_4 fin
```

El script imprime el PC final de cada etapa y el de `fin`. Si cambian, hay que actualizar los parámetros de `tb_profesor` o `tb_propio`. Los estados esperados que calcula el modelo para el programa del profesor coinciden con los del anexo del enunciado.

## Cómo funciona `tb_evaluacion`

- Ejecuta el programa en A, B y C con el mismo reloj.
- **Comprobación por etapas.** Cada arquitectura reconstruye su banco de registros con las escrituras de WB, en el orden del programa (vía 0 antes que vía 1, sin contar las instrucciones anuladas). Cuando la última instrucción de una etapa llega a WB, compara los 32 registros y la memoria con el estado esperado.
- **Señales de comprobación** para las waveforms, por arquitectura (`a_`, `b_`, `c_`):
  - `chk` vale 1 durante el ciclo de la comprobación;
  - `etapa` indica la etapa comprobada (0 a 3);
  - `ok[k]` queda en 1 si la etapa k coincidió.
- **Rendimiento:**
  - Ciclos: hasta la última escritura útil (un registro distinto de `x0` o la memoria).
  - Instrucciones retiradas: las que pasan de EX a MEM sin anularse, con PC menor que `fin`. El bucle final `fin` no se cuenta.
  - También cuenta pausas (`StallD`), flushes, emisiones dobles y, en C, saltos resueltos y fallos de predicción.

La memoria de datos (`Pipeline_E1/dmem.v`) se amplió a 1024 palabras (4 KB) para que la base 1536 del programa del profesor sea una dirección real.

## Resultados

**Programa del profesor**

| Indicador | Pipeline | Dual-Issue | Optimizado |
| --- | --- | --- | --- |
| Ciclos totales | 458 | 386 | 291 |
| Instrucciones retiradas | 312 | 312 | 312 |
| CPI | 1.47 | 1.24 | 0.93 |
| IPC | 0.68 | 0.81 | 1.07 |
| Speedup vs. pipeline | 1.00 | 1.19 | 1.57 |
| Speedup vs. Dual-Issue | | 1.00 | 1.33 |
| Flushes (fallos en C) | 68 | 68 | 33 |

En C se resolvieron 90 saltos y se predijeron bien 57 (63 %).

**Programa propio**

| Indicador | Pipeline | Dual-Issue | Optimizado |
| --- | --- | --- | --- |
| Ciclos totales | 730 | 591 | 501 |
| Instrucciones retiradas | 546 | 546 | 546 |
| CPI | 1.34 | 1.08 | 0.92 |
| IPC | 0.75 | 0.92 | 1.09 |
| Speedup vs. pipeline | 1.00 | 1.24 | 1.46 |
| Speedup vs. Dual-Issue | | 1.00 | 1.18 |
| Pausas (Load-Use) | 36 | 36 | 36 |
| Flushes (fallos en C) | 73 | 73 | 37 |

En C se resolvieron 106 saltos y se predijeron bien 69 (65 %).

En los dos programas, las cuatro etapas coinciden en las tres arquitecturas.

## Waveforms en Vivado

Con la simulación de `tb_profesor` abierta, en la Tcl Console:

```
source [get_property DIRECTORY [current_project]]/Evaluacion_EF/ondas_ef.tcl
ondas_profesor
```

Si `source` no encuentra el archivo, usar la ruta completa a `Evaluacion_EF/ondas_ef.tcl` dentro de la carpeta del proyecto. Si se modificó algún `.v`, primero hay que relanzar la simulación (**Relaunch Simulation**).

Se abren seis ventanas de ondas y se guardan como `ef_prof_*.wcfg`. Para el programa propio, con `tb_propio` abierto, se usa `ondas_propio` (cuatro ventanas, `ef_propio_*.wcfg`). Después se pueden reabrir con **File > Simulation Waveform > Open Configuration** seguido de `restart` y `run all`.

`chk` sube en el flanco de subida del ciclo en que la última instrucción de la etapa está en WB, y dura un ciclo (10 ns). Las ventanas de la tabla son las que hay que mostrar con zoom.

Al final de cada ventana está la **instrucción que hay en cada etapa** (`00000000` = burbuja o instrucción anulada):
- En el Pipeline: `PCF`, `InstrF`, `InstrD`, `InstrE`, `InstrM` e `InstrW`.
- En el Dual-Issue y el optimizado: `PCF`, `InstrF_0`/`InstrF_1`, `PCD`, y las dos posiciones de ID, EX, MEM y WB (`InstrD_0`/`InstrD_1` … `InstrW_0`/`InstrW_1`). Los registros `InstrE/M/W_0/1` de `dual_datapath` y `bp_datapath` son solo para las ondas y no intervienen en la ejecución.

**Programa del profesor**

| Configuración | Ventana | Qué mostrar |
| --- | --- | --- |
| `ef_prof_etapas_pipeline` | 185–215, 325–355, 3625–3655, 4595–4625 ns | `a_chk` en 1 a los 195, 335, 3635 y 4605 ns (etapas A–D), con `a_ok` subiendo hasta `1111`, más los registros y la memoria de esa etapa. |
| `ef_prof_etapas_dual` | 125–155, 255–285, 3125–3155, 3875–3905 ns | `b_chk` a los 135, 265, 3135 y 3885 ns. |
| `ef_prof_etapas_opt` | 125–155, 255–285, 2205–2235, 2925–2955 ns | `c_chk` a los 135, 265, 2215 y 2935 ns. |
| `ef_prof_doble_memoria` | 25–115 ns | 25–85: seis pares completos (`Issue1D = 1`). 85–105: pares `sw`+`sw` y `sw`+`lw` con `MemConflict = 1`. 105–115: RAW `lw x11` / `add x12, x11, x6`. |
| `ef_prof_loaduse` | 105–235 ns | 115–125: `StallD = 1` (`add x12` espera a `lw x11`). 135–145: `BlockIssue1D = 1` (`sub x15` depende del `lw x13` en EX). 145–155 y 205–215: pausas Load-Use. 165–195: conflictos `sw`/`lw` seguidos. |
| `ef_prof_predictor` | 275–800 ns | Bucle C1 (`beq x25, x2, C1` en PC 124, 12 vueltas). B: `PCSrcE`/`FlushD` en cada vuelta, una vuelta cada 50 ns, el bucle termina cerca de 795 ns. C: falla solo en la primera vuelta (275–285) y en la salida (575–585); en las demás `PredF` = 1, `PTgtF` = 112 y no hay flush; termina cerca de 595 ns. `x19` cuenta las vueltas en las dos. |

**Programa propio**

| Configuración | Ventana | Qué mostrar |
| --- | --- | --- |
| `ef_propio_etapas_pipeline` | `a_chk` a los 825, 2175, 3235 y 7315 ns | Etapas 1 a 4. |
| `ef_propio_etapas_dual` | `b_chk` a los 705, 1775, 2495 y 5925 ns | |
| `ef_propio_etapas_opt` | `c_chk` a los 555, 1425, 2015 y 5025 ns | |
| `ef_propio_predictor` | 2100–3300 ns | Bucle interno del ordenamiento (`beq x6, x31, B2` en PC 260). En C falla al entrar y al salir de cada pasada y acierta en el resto; en B hay flush en cada vuelta. También se ven las pausas Load-Use (`StallD`). |

## Simulación

**En Vivado:** los archivos ya están en el proyecto. En `sim_1`, elegir `tb_profesor` o `tb_propio` como top y correr la simulación. El tiempo de simulación del proyecto quedó en 20 µs, y el testbench termina solo a los 15 µs.

**Con Icarus Verilog**, desde Ubuntu (WSL) o Linux:

```
sudo apt install iverilog
cd <carpeta del proyecto>/Evaluacion_EF
bash correr_icarus.sh            # programa del profesor y programa propio
bash correr_icarus.sh profesor   # solo uno: profesor o propio
```

En WSL, la carpeta del proyecto se ve como `/mnt/c/Users/<usuario>/...`. El script compila las tres arquitecturas, imprime los mismos resultados que Vivado y guarda las ondas en `sim/tb_profesor.vcd` y `sim/tb_propio.vcd`. Para verlas: `sudo apt install gtkwave` y `gtkwave sim/tb_profesor.vcd`. La carpeta `sim/` está en el `.gitignore`.
