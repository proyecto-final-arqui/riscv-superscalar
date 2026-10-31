# Control del pipeline - E1

Esta carpeta contiene el control preparado para un pipeline Single-Issue de cinco etapas. Todavía falta conectarlo a un datapath con registros entre etapas y a la Hazard Unit. El avance Dual-Issue de src_files sigue usando su controller de un solo ciclo. Esta carpeta es un avance separado; no se ha conectado al procesador ni agregado al proyecto Vivado.

## Archivos

- `controller_pipeline.v`: nuevo controller con decodificación en ID y registros de control para EX, MEM y WB. Resuelve BEQ/JAL en EX y recibe `FlushE`.
- `maindec.v`: copia adaptada del decodificador original. Los opcodes desconocidos desactivan el control. Para tipo R, ImmSrc vale 00 en lugar de xx; no se usa el inmediato en esas operaciones.
- `aludec.v`: conserva las operaciones originales. La salida se declara como reg para asignarla directamente en el bloque combinacional; se elimina el registro intermedio. Comentarios cortos.
- `testbench_controller.v`: prueba aislada del controller. Comprueba reset, avance entre etapas, cargas, stores, burbujas, BEQ y JAL. Genera controller.vcd al ejecutarse.

## Señales y conexión pendiente

D significa Decode, E Execute, M Memory y W Writeback.

- `opD`, `funct3D` y `funct7b5D` deben salir de la instrucción guardada en IF/ID.
- `ImmSrcD` se usa para extender el inmediato en ID.
- `ALUSrcE` y `ALUControlE` se usan en EX.
- `ZeroE` debe venir de la ALU de EX, con los operandos corregidos por forwarding.
- `PCSrcE` seleccionará el destino del salto calculado para la instrucción en EX.
- `MemWriteM` habilitará la escritura de memoria en MEM.
- `RegWriteW` y `ResultSrcW` controlarán la escritura del resultado en WB.
- `RegWriteE`, `RegWriteM`, `ResultSrcE` y `ResultSrcM` quedan disponibles para la Hazard Unit. Una carga en EX se identifica por `RegWriteE` y `ResultSrcE == 2'b01`.
- `JumpE` indica un JAL en EX. Su PC+4 debe viajar por el datapath hasta WB.

Para Load-Use, la Hazard Unit deberá detener PC e IF/ID mediante StallF/StallD y activar FlushE. El controller introduce una burbuja en EX, mientras la carga anterior avanza a MEM. No se detienen EX, MEM ni WB en este caso.

Cuando se toma un salto en EX, la Hazard Unit deberá limpiar IF/ID y activar FlushE para anular las instrucciones más jóvenes. FlushE limpia el control que entra a EX en el siguiente flanco; no cancela la instrucción que ya está en EX. El datapath también deberá limpiar sus registros ID/EX. MEM y WB siguen avanzando para conservar las instrucciones anteriores.

El diseño supone memorias con el comportamiento de la base original, sin esperas adicionales. Todavía no maneja una pausa global por memoria lenta. El decodificador conserva el subconjunto de instrucciones del SingleCycle; no valida todas las combinaciones ilegales de funct3/funct7 ni añade nuevas instrucciones.

## Prueba

Compilar únicamente los cuatro archivos Verilog de esta carpeta para la prueba aislada. No mezclar los decodificadores de src_files y Pipeline_E1 en la misma compilación: tienen los mismos nombres de módulo. Para probar este controller en Vivado, usar un proyecto de simulación separado con estos cuatro archivos y seleccionar testbench_controller como módulo principal.

Si se utiliza Icarus Verilog, ejecutar desde esta carpeta:

```text
iverilog -s testbench_controller -o controller_test controller_pipeline.v maindec.v aludec.v testbench_controller.v
vvp controller_test
```

Resultado esperado: `Prueba del controller correcta`.

Estado: revisión estática realizada; simulación pendiente porque no se encontró un simulador Verilog disponible. Esta prueba no sustituye los cuatro programas completos exigidos para E1.
