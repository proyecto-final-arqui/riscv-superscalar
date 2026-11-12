# Dual-Issue con predictor de saltos de 2 bits y BTB

Optimización para la entrega final: arquitectura **C**. Parte del Dual-Issue de `Dual_E1` (arquitectura **B**), que queda sin cambios, y reutiliza `dual_fetch`, `dual_regfile`, `dual_issue` y `dual_hazard`.

## Limitación que resuelve

En el Dual-Issue los saltos se resuelven en EX. Cada salto tomado vacía IF/ID e ID/EX: se pierden 2 ciclos, hasta 4 espacios de emisión. En los bucles, el salto de vuelta se paga en cada vuelta.

## Funcionamiento

- **BTB con contadores de 2 bits** (`bp_predictor.v`, 16 entradas por defecto). Cada entrada tiene `valid`, `tag` (PC[31:6]), destino y un contador saturado: `00`/`01` predicen no tomado y `10`/`11` predicen tomado. Un salto nuevo se guarda en `10` si se tomó o en `01` si no.
- **Predicción en IF.** Se consulta el BTB con `PCF` y `PCF + 4`:
  - Si I0 se predice tomada, I1 es del camino equivocado y entra a IF/ID como vacía (`0`). El PC siguiente es el destino de I0.
  - Si solo I1 se predice tomada, entra el par y el PC siguiente es el destino de I1.
  - Si se reagrupa, solo entra `InstrF_0`, y el PC siguiente es su destino o `PCF + 4`.
- **IF/ID guarda un PC por posición** (`PCD`, `PCD_1`). Con predicción, las dos instrucciones del par ya no son siempre consecutivas.
- **La predicción viaja hasta EX** (`PredE_0/1`, `PTgtE_0/1`). Allí se compara con el resultado real:
  - `MisE = tomado ? (no predicho o destino distinto) : predicho tomado`
  - Solo si hay fallo (`RedirectE`) se vacía el pipeline. El PC se corrige al destino real o a la instrucción siguiente al salto.
  - Si falla I0, la I1 que salió con ella se anula, igual que en B.
- **Actualización en EX.** El `beq` o `jal` que está en EX actualiza su contador y su destino. El destino lo calcula el mismo sumador único de saltos.

## Archivos

| Archivo | Contenido |
| --- | --- |
| `bp_predictor.v` | BTB con contadores de 2 bits: dos lecturas en IF y una escritura desde EX. |
| `bp_datapath.v` | `dual_datapath` con predicción en IF, PC por posición en IF/ID, predicción en ID/EX y corrección del PC. |
| `bp_decode.v` | `dual_decode`: el flush y la anulación de I1 dependen de un fallo de predicción; agrega `CtrlE` para actualizar el BTB. |
| `bp_riscv.v`, `bp_top.v` | Conexión del procesador y de las memorias. |
| `tb_bp.v` | Ejecuta cada programa en A, B y C a la vez. Compara registros, memoria y el orden de las instrucciones completadas, y mide ciclos, saltos y fallos. |

`Pipeline_E1/program7.mem` es un bucle de 10 vueltas para medir el predictor.

## Resultados (`tb_bp`)

| Programa | Instr. | Ciclos A | Ciclos B | Ciclos C | Saltos | Fallos C | Flushes B |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 25 | 29 | 18 | 18 | 1 | 0 | 0 |
| 2 | 20 | 24 | 20 | 20 | 0 | 0 | 0 |
| 3 | 24 | 33 | 26 | 26 | 0 | 0 | 0 |
| 4 | 25 | 44 | 37 | 35 | 10 | 6 | 7 |
| 5 | 36 | 43 | 32 | 32 | 3 | 2 | 2 |
| 6 | 21 | 32 | 23 | 23 | 5 | 3 | 3 |
| 7 - bucle | 68 | 95 | 63 | 45 | 21 | 2 | 11 |

En el bucle, el predictor acierta 19 de 21 saltos (90 %): falla solo el `jal` en la primera vuelta (arranque en frío) y el `beq` al salir. B pasa de 63 a 45 ciclos (speedup 1.40). En programas cuyos saltos se ejecutan una sola vez (5 y 6), el contador nunca se entrena y no hay mejora: es el caso en que el predictor no ayuda.

También se verificó con 60 programas aleatorios con bucles, con BTB de 16 y de 2 entradas: A, B y C dan el mismo resultado y C completa las mismas instrucciones en el mismo orden.

## Simulación

Con Icarus, desde una carpeta con los `program*.mem`:

```
iverilog -g2005 -o bp -s tb_bp ../Pipeline_E1/{alu,aludec,controller_pipeline,datapath_pipeline,dmem,extend,hazard_unit,imem,maindec,regfile,riscv_pipeline,top_pipeline}.v ../Dual_E1/dual_*.v ../Opt_BP/bp_*.v ../Opt_BP/tb_bp.v
vvp bp
```

En Vivado: agregar los `bp_*.v` a Design Sources, `tb_bp.v` y `program7.mem` a Simulation Sources, y elegir `tb_bp` como top. Corre 200 ciclos: ajustar el tiempo de simulación a 2100 ns.
