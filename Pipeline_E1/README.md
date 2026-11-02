# Control del pipeline - E1

Esta carpeta contiene el control preparado para un pipeline Single-Issue de cinco etapas. La Hazard Unit ya está instanciada dentro del controller. Todavía falta conectar este conjunto a un datapath con registros entre etapas. El avance Dual-Issue de src_files sigue usando su controller de un solo ciclo. Pipeline_E1 se mantiene separado y todavía no está conectado al datapath ni agregado al proyecto Vivado.

## Archivos

- `controller_pipeline.v`: nuevo controller con decodificación en ID y registros de control para EX, MEM y WB. Resuelve BEQ/JAL en EX e instancia hazard_unit. Recibe los números de registros de las etapas y entrega forwarding, stalls y flushes.
- `maindec.v`: copia adaptada del decodificador original. Los opcodes desconocidos desactivan el control. Para tipo R, ImmSrc vale 00 en lugar de xx; no se usa el inmediato en esas operaciones.
- `aludec.v`: conserva las operaciones originales. La salida se declara como reg para asignarla directamente en el bloque combinacional; se elimina el registro intermedio. Comentarios cortos.
- `testbench_controller.v`: prueba conjunta del controller y la Hazard Unit. Comprueba 18 condiciones de reset, Load-Use, forwarding, stores, BEQ y JAL. Simula los números de registro de las etapas, pero no incluye un datapath ni ejecuta operaciones sobre datos.

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

Para esta prueba, compilar controller_pipeline.v, maindec.v, aludec.v, hazard_unit.v y testbench_controller.v. Usar testbench_controller como módulo principal. No mezclar los decodificadores de src_files y Pipeline_E1 en la misma compilación: tienen los mismos nombres de módulo.

Si se utiliza Icarus Verilog, ejecutar desde esta carpeta:

```text
iverilog -s testbench_controller -o controller_test controller_pipeline.v maindec.v aludec.v hazard_unit.v testbench_controller.v
vvp controller_test
```

Resultado esperado: `Controller y Hazard Unit: 18 comprobaciones correctas`.

Estado actualizado el 2 de noviembre de 2026: la prueba conjunta pasó sus 18 comprobaciones en Vivado Simulator 2025.2, con escala de simulación de 1ns/1ps. El resultado y las formas de onda se guardaron localmente en ../tmp/control_hazard_sim; no se incluyen en este repositorio. Esta prueba no sustituye los cuatro programas completos de E1 ni verifica un datapath.

## Hazard Unit

Se agregaron `hazard_unit.v` y `testbench_hazard.v` para el pipeline Single-Issue de E1. La prueba aislada pasó 33 casos en Vivado. [HAZARD.md](HAZARD.md) explica las entradas, salidas, resultados de simulación y las conexiones pendientes con el datapath. La conexión se realizó en el controller existente; no se creó un tercer módulo de conexión.


## Cambio de interfaz del controller

- Se agregaron las entradas Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM y RdW. Las proporcionará el datapath.
- Se agregaron las salidas ForwardAE, ForwardBE, StallF, StallD y FlushD.
- FlushE ahora es una salida, no una entrada. La genera la instancia interna de hazard_unit y el controller la utiliza para limpiar EX. No debe tener otro controlador externo.
- hazard_unit.v sigue siendo un archivo separado y debe incluirse al compilar el controller. No hace falta instanciar otra Hazard Unit fuera de él.
- Los archivos del datapath original y del repositorio de tu compañero no se modificaron.
