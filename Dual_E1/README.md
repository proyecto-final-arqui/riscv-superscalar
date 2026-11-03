# Dual-Issue preliminar - E1

Datapath pipelined de cinco etapas con dos vías. Usa `alu.v`, `aludec.v`, `maindec.v`, `extend.v`, `dmem.v` y `hazard_unit.v` de `Pipeline_E1`.

## Archivos

| Archivo | Contenido |
| --- | --- |
| `dual_fetch.v` | Dual Fetch: lee las instrucciones de PC y PC+4 en el mismo ciclo. |
| `dual_regfile.v` | Banco de registros con 4 lecturas y 2 escrituras. Si las dos vías escriben el mismo registro, gana la vía 1 porque es la más joven. |
| `dual_decode.v` | Dual Decode (dos `maindec` y dos `aludec`), control por etapas de las dos vías, mux del puerto de memoria y Hazard Unit de la vía 0. |
| `dual_datapath.v` | IF/ID con dos instrucciones, dos `extend`, ID/EX, EX/MEM y MEM/WB para las dos vías, dos ALU, un puerto de memoria y dos escrituras en WB. |
| `dual_riscv.v`, `dual_top.v` | Conexión del procesador y de las memorias. |
| `tb_dual.v` | Ejecuta los programas 1 a 4 en el Single-Issue y en el Dual a la vez, y compara los registros y la memoria. |

## Fetch y reagrupamiento

IF/ID guarda un par `(I0, I1)` con su PC (`PCD`). Mientras el par sea válido, se cumple `PCF = PCD + 8`.

- Si salen las dos instrucciones, o si ID está vacío después de un reset o flush: entra el par nuevo `(InstrF_0, InstrF_1)` y el PC avanza 8.
- Si solo sale I0: I1 pasa a la posición 0 y se completa el par con `InstrF_0`. El PC avanza 4. Así no se pierde ni se repite ninguna instrucción.
- Un salto tomado carga `PCTargetE` y vacía IF/ID. Un Load-Use conserva el PC y IF/ID, igual que en el pipeline original.

## Estado en E1

`Issue1D = 0` en `dual_decode.v`: la vía 1 decodifica, pero todavía no emite. La instrucción joven siempre se reagrupa y sale por la vía 0 en el ciclo siguiente, así que el resultado y los ciclos son iguales a los del Single-Issue. La rúbrica permite esto: en E1 todavía no se exige la ejecución simultánea.

Para E2 falta lo siguiente:

1. La Issue Unit que calcula `Issue1D` (RAW dentro del par, memoria, saltos, Load-Use de I1).
2. El forwarding hacia la vía 1 y entre vías. Ahora EX de la vía 1 lee directamente del banco.
3. Un recurso de saltos compartido que también reciba los saltos de la vía 1.
4. Hazards de la vía 1 en la Hazard Unit.

## Simulación

En Vivado: agregar los archivos `.v` de esta carpeta (menos el testbench) a `sources_1`, agregar `tb_dual.v` a `sim_1` y elegirlo como top. Los `.mem` ya están en `sim_1`.

Con Icarus, desde `Pipeline_E1`:

```
iverilog -o dual alu.v aludec.v controller_pipeline.v datapath_pipeline.v dmem.v extend.v hazard_unit.v imem.v maindec.v regfile.v riscv_pipeline.v top_pipeline.v ../Dual_E1/*.v
vvp dual
```

Señales para la waveform: `dual.rv.dp.PCF`, `InstrF_0`, `InstrF_1`, `PCD`, `InstrD_0`, `InstrD_1`, `LoadPairD`, `ValidD`, y en `dual.rv.c`: `RegWriteD_0/1`, `ALUControlD_0/1`, `ImmSrcD_0/1` y `Issue1D`.
