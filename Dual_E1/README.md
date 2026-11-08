# Dual-Issue

Pipeline de cinco etapas con dos vías que emite hasta dos instrucciones por ciclo, en orden. Usa `alu.v`, `aludec.v`, `maindec.v`, `extend.v` y `dmem.v` de `Pipeline_E1`.

## Archivos

| Archivo | Contenido |
| --- | --- |
| `dual_fetch.v` | Dual Fetch: lee las instrucciones de PC y PC+4 en el mismo ciclo. |
| `dual_regfile.v` | Banco de registros con 4 lecturas y 2 escrituras. Si las dos vías escriben el mismo registro, gana la vía 1 porque es la más joven. |
| `dual_decode.v` | Dual Decode (dos `maindec` y dos `aludec`), control por etapas de las dos vías y mux del puerto de memoria. |
| `dual_issue.v` | Issue Unit: decide si I1 sale junto con I0. |
| `dual_hazard.v` | Forwarding entre vías, Load-Use y saltos. |
| `dual_datapath.v` | IF/ID con dos instrucciones, dos `extend`, registros de pipeline de las dos vías, dos ALU, un puerto de memoria y dos escrituras en WB. |
| `dual_riscv.v`, `dual_top.v` | Conexión del procesador y de las memorias. |
| `tb_dual.v` | Ejecuta los programas 1 a 6 en el Single-Issue y en el Dual a la vez, compara registros y memoria, y mide los ciclos. |
| `tb_orden.v` | Ejecuta los programas 1 a 6 en las dos arquitecturas y compara la secuencia de instrucciones (PC y palabra) que pasan de EX a MEM. Demuestra que el reagrupamiento respeta el orden del programa y que no se pierden ni se duplican instrucciones. Con `TRACE(1)` muestra qué sale por cada vía en cada ciclo. |

`Pipeline_E1/program5.mem` y `Pipeline_E1/program6.mem` prueban los casos de dos vías. El 6 cubre memoria en las dos posiciones del par, el conflicto del puerto de memoria y saltos en la primera y segunda posición, tomados y no tomados.

## Fetch y reagrupamiento

IF/ID guarda un par `(I0, I1)` con su PC (`PCD`). Mientras el par sea válido, se cumple `PCF = PCD + 8`.

- Si salen las dos instrucciones, o si ID está vacío después de un reset o flush: entra el par nuevo `(InstrF_0, InstrF_1)` y el PC avanza 8.
- Si solo sale I0: I1 pasa a la posición 0 y se completa el par con `InstrF_0`. El PC avanza 4. Así no se pierde ni se repite ninguna instrucción.
- Un salto tomado carga `PCTargetE` y vacía IF/ID. Un Load-Use conserva el PC y IF/ID.
- Si el salto tomado es I0, I1 (más joven) se anula entre EX y MEM. Si el salto es I1, I0 es más antigua y continúa.

## Issue Unit

I1 sale junto con I0 (`Issue1D = 1`) solo si se cumplen todas estas condiciones:

| Condición | Motivo |
| --- | --- |
| I1 es una instrucción soportada (tipo R, tipo I, `lw`, `sw`, `beq` o `jal`) | Las dos vías aceptan todas las instrucciones. |
| I0 e I1 no son las dos `lw`/`sw` | Hay un solo puerto de memoria. |
| I0 e I1 no son las dos `beq`/`jal` | Hay un solo recurso de resolución de saltos. |
| I0 no es `jal` | Un `jal` siempre salta: I1 sería anulada. Con un `beq` en I0, I1 sí sale y se anula solo si el salto se toma. |
| I1 no lee el registro que escribe I0 | Es un RAW dentro del par: el dato aún no existe. |
| I1 no necesita el dato de un `lw` que está en EX (`BlockIssue1D`) | Es un Load-Use para I1: el dato de memoria todavía no está. |
| I0 no está en pausa | I1 no puede adelantarse a I0. |

La memoria y el salto se asignan a la vía donde esté la instrucción: `MemSelM` elige la dirección y el dato del puerto de memoria, y `BranchSelE` elige `PCE_0 + ImmExtE_0` o `PCE_1 + ImmExtE_1` como `PCTargetE`.

Si I1 no sale, se reagrupa y en el ciclo siguiente sale por la vía 0, donde se aplican las reglas del pipeline original.

## Forwarding

Cada operando de EX (`ForwardAE_0`, `ForwardBE_0`, `ForwardAE_1`, `ForwardBE_1`) elige entre:

| Selector | Dato |
| --- | --- |
| 000 | Registro leído en ID |
| 100 | MEM de la vía 1 |
| 011 | MEM de la vía 0 (PC+4 si es `jal`) |
| 010 | WB de la vía 1 |
| 001 | WB de la vía 0 |

La prioridad sigue el orden de la tabla, de 100 a 001: gana el productor más joven. MEM es más joven que WB y, dentro de la misma etapa, la vía 1 es más joven que la vía 0. Una carga en MEM no se reenvía: la pausa Load-Use garantiza que, cuando el dato se necesite, la carga ya esté en WB.

## Resultados

| Programa | Single (ciclos) | Dual (ciclos) | Emisiones dobles |
| --- | --- | --- | --- |
| 1 - ISA | 29 | 18 | 11 |
| 2 - Forwarding | 24 | 20 | 6 |
| 3 - Stalling | 33 | 26 | 9 |
| 4 - Flushing | 44 | 37 | 10 |
| 5 - Dual | 43 | 32 | 13 |
| 6 - Memoria y saltos en las dos vías | 32 | 23 | 10 |

Los ciclos se cuentan hasta la última escritura en un registro o en la memoria. Los seis programas dan el mismo resultado en las dos arquitecturas.

## Pendiente

- Contar instrucciones retiradas para calcular IPC y CPI.

## Simulación

En Vivado: `project_1.xpr` ya incluye los `dual_*.v` y los programas en Design Sources, y los `tb_*.v` en Simulation Sources. En `sim_1`, clic derecho sobre `tb_dual` o `tb_orden` → **Set as Top** y correr la simulación.

Con Icarus, desde `Pipeline_E1`:

```
iverilog -o dual alu.v aludec.v controller_pipeline.v datapath_pipeline.v dmem.v extend.v hazard_unit.v imem.v maindec.v regfile.v riscv_pipeline.v top_pipeline.v ../Dual_E1/*.v
vvp dual
```

Señales para la waveform: `dual.rv.dp.PCF`, `PCD`, `InstrD_0`, `InstrD_1`, `LoadPairD`, y en `dual.rv.c`: `Issue1D`, `BlockIssue1D`, `MemSelM`, `BranchSelE`, `PCSrcE`, `StallD`, `FlushD`, `ForwardAE_0/1`, `ForwardBE_0/1`.
