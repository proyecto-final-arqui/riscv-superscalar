# RISC-V Pipeline + Superescalar (Proyecto 2)

Tres arquitecturas RV32I (`add`, `sub`, `and`, `or`, `slt`, `addi`, `andi`, `ori`, `slti`, `lw`, `sw`, `beq`, `jal`):

| Carpeta | Arquitectura | Detalle |
|---|---|---|
| `Pipeline_E1` | (A) Pipeline Single-Issue de 5 etapas | Hazard Unit con forwarding, stalling y flushing. Programas 1 a 4 de la E1. |
| `Dual_E1` | (B) Dual-Issue In-Order | Issue Unit, forwarding entre vías, un puerto de memoria y un recurso de saltos compartidos. Ver [Dual_E1/README.md](Dual_E1/README.md). |
| `Opt_BP` | (C) Dual-Issue con predictor de saltos de 2 bits y BTB | Optimización de la entrega final. Ver [Opt_BP/README.md](Opt_BP/README.md). |
| `Evaluacion_EF` | Evaluación final | Programa del profesor, programa propio y comparación de A, B y C. Ver [Evaluacion_EF/README.md](Evaluacion_EF/README.md). |

## Abrir el proyecto

Abrir `project_1.xpr` en Vivado. Todos los archivos `.v` y `.mem` ya están en el proyecto.

## Correr un testbench

1. En **Sources → Simulation Sources → sim_1**, clic derecho sobre el testbench → **Set as Top**.
2. **Flow Navigator → Run Simulation → Run Behavioral Simulation**.
3. Revisar el resultado en la Tcl Console. El tiempo de simulación del proyecto es 20 µs y todos los testbenches terminan solos.

| Testbench | Qué prueba | Mensaje si todo está bien |
|---|---|---|
| `testbench_program1` … `testbench_program4` | Pipeline (A) con los programas 1 a 4 | `PROGRAMA N (...): CORRECTO` |
| `tb_dual` | Dual-Issue (B) contra el pipeline, programas 1 a 6 | `DUAL: CORRECTO en los 6 programas` |
| `tb_orden` | B completa las instrucciones en el mismo orden que A, sin perder ni duplicar | `ORDEN: CORRECTO en los 6 programas` |
| `tb_dual_hazard` | Hazard Unit del Dual-Issue, prueba aislada | `HAZARD DUAL: CORRECTO, 67 comprobaciones` |
| `tb_bp` | A, B y C con los programas 1 a 7 | `PREDICTOR: CORRECTO en los 7 programas` |
| `tb_profesor` | Programa del profesor en A, B y C: etapas A a D y rendimiento | `RESULTADO: CORRECTO en las tres arquitecturas` |
| `tb_propio` | Programa propio en A, B y C: etapas 1 a 4 y rendimiento | `RESULTADO: CORRECTO en las tres arquitecturas` |

## Cargar las ondas

Con la simulación abierta, en la Tcl Console se carga el script de ondas que corresponda. Cada script crea las ventanas de ondas con las señales ya ordenadas y las guarda como `.wcfg`.

| Simulación abierta | Comandos |
|---|---|
| `testbench_programN` | `source [get_property DIRECTORY [current_project]]/Pipeline_E1/ondas.tcl` y luego `ondas N` |
| `tb_dual` / `tb_orden` | `source [get_property DIRECTORY [current_project]]/Dual_E1/ondas_dual.tcl` y luego `ondas_dual` / `ondas_orden` |
| `tb_profesor` / `tb_propio` | `source [get_property DIRECTORY [current_project]]/Evaluacion_EF/ondas_ef.tcl` y luego `ondas_profesor` / `ondas_propio` |

Si `source` no encuentra el archivo, se puede usar la ruta completa al `.tcl` dentro de la carpeta del proyecto. Las ventanas de tiempo de cada figura están en el README de cada carpeta.

## Sin Vivado: Icarus Verilog

Si Vivado no puede simular (por ejemplo, si Windows bloquea el simulador con Smart App Control), los programas de la evaluación final también corren con Icarus Verilog desde Ubuntu (WSL):

```
sudo apt install iverilog
cd <carpeta del proyecto>/Evaluacion_EF
bash correr_icarus.sh
```

## Programas

| Programa | Prueba |
|---|---|
| 1 | ISA sin dependencias |
| 2 | Forwarding |
| 3 | Stalling (Load-Use) |
| 4 | Flushing (saltos) |
| 5 | Dual-Issue: RAW y WAW dentro del par, forwarding entre vías, Load-Use de I1 |
| 6 | Dual-Issue: memoria y saltos en las dos posiciones del par |
| 7 | Bucle de 10 vueltas para medir el predictor |
| `Evaluacion_EF/profesor.s` | Programa del profesor (etapas A a D) |
| `Evaluacion_EF/propio.s` | Programa propio (etapas 1 a 4) |
