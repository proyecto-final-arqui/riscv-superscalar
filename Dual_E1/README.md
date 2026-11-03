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
| `tb_dual.v` | Ejecuta los programas 1 a 5 en el Single-Issue y en el Dual a la vez, compara registros y memoria, y mide los ciclos. |

`Pipeline_E1/program5.mem` es un programa para probar los casos de dos vías.

## Fetch y reagrupamiento

IF/ID guarda un par `(I0, I1)` con su PC (`PCD`). Mientras el par sea válido, se cumple `PCF = PCD + 8`.

- Si salen las dos instrucciones, o si ID está vacío después de un reset o flush: entra el par nuevo `(InstrF_0, InstrF_1)` y el PC avanza 8.
- Si solo sale I0: I1 pasa a la posición 0 y se completa el par con `InstrF_0`. El PC avanza 4. Así no se pierde ni se repite ninguna instrucción.
- Un salto tomado carga `PCTargetE` y vacía IF/ID. Un Load-Use conserva el PC y IF/ID.

## Issue Unit

I1 sale junto con I0 (`Issue1D = 1`) solo si se cumplen todas estas condiciones:

| Condición | Motivo |
| --- | --- |
| I1 es una operación ALU (tipo R o tipo I) | La vía 1 todavía no hace `lw`, `sw`, `beq` ni `jal`. |
| I0 no es `beq` ni `jal` | Si I0 salta, I1 puede ser del camino equivocado. |
| I1 no lee el registro que escribe I0 | Es un RAW dentro del par: el dato aún no existe. |
| I1 no necesita el dato de un `lw` que está en EX | Es un Load-Use para I1: el dato de memoria todavía no está. |
| I0 no está en pausa | I1 no puede adelantarse a I0. |

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
| 1 - ISA | 29 | 20 | 9 |
| 2 - Forwarding | 24 | 20 | 6 |
| 3 - Stalling | 33 | 30 | 5 |
| 4 - Flushing | 44 | 40 | 5 |
| 5 - Dual | 39 | 32 | 8 |

Los ciclos se cuentan hasta la última escritura en un registro o en la memoria. Los cinco programas dan el mismo resultado en las dos arquitecturas.

## Pendiente

- Permitir `lw`/`sw` y saltos en la vía 1. Así se podría emitir ALU + memoria en cualquier orden y un salto en la segunda posición del par, como pide el enunciado.
- Ajustar la Hazard Unit para las cargas de la vía 1.

## Simulación

En Vivado: agregar los archivos `.v` de esta carpeta (menos `tb_dual.v`) a `sources_1`, agregar `tb_dual.v` y `program5.mem` a `sim_1`, y elegir `tb_dual` como top.

Con Icarus, desde `Pipeline_E1`:

```
iverilog -o dual alu.v aludec.v controller_pipeline.v datapath_pipeline.v dmem.v extend.v hazard_unit.v imem.v maindec.v regfile.v riscv_pipeline.v top_pipeline.v ../Dual_E1/*.v
vvp dual
```

Señales para la waveform: `dual.rv.dp.PCF`, `PCD`, `InstrD_0`, `InstrD_1`, `LoadPairD`, y en `dual.rv.c`: `Issue1D`, `StallD`, `FlushD`, `ForwardAE_0/1`, `ForwardBE_0/1`.
