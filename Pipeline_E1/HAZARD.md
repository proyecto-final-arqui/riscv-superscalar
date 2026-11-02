# Hazard Unit - E1

La unidad corresponde al pipeline Single-Issue de cinco etapas. Es combinacional: toma las señales actuales y decide forwarding, pausas y limpieza. No necesita reloj ni reset propios. Está instanciada dentro de controller_pipeline.v, que se conecta al datapath en riscv_pipeline.v.

## Archivos

- `hazard_unit.v`: detecta dependencias y genera las señales de control.
- `testbench_hazard.v`: prueba 33 casos de forwarding, Load-Use, registros fuente y saltos.

## Entradas

| Entrada | De dónde viene |
| --- | --- |
| opD | Opcode de la instrucción en ID. |
| Rs1D, Rs2D | Campos de registros fuente de la instrucción en ID. |
| Rs1E, Rs2E | Números de registros fuente guardados en ID/EX. |
| RdE, RdM, RdW | Registro destino que acompaña a cada instrucción por EX, MEM y WB. |
| RegWriteE, RegWriteM, RegWriteW | Salidas del controller de las etapas correspondientes. |
| ResultSrcE, ResultSrcM | Salidas del controller; 01 identifica una carga. |
| PCSrcE | Salida del controller que indica un salto tomado en EX. |

La unidad obtiene internamente UseRs1D y UseRs2D a partir de opD. R, SW y BEQ leen ambos registros. LW y las operaciones inmediatas leen rs1. JAL no lee ninguno. Esto corresponde al subconjunto de instrucciones del procesador original; si se agregan instrucciones, revisar esta tabla.

## Forwarding

| Selector | Dato seleccionado |
| --- | --- |
| 00 | Valor leído del banco de registros y guardado en ID/EX. |
| 10 | Resultado disponible de la instrucción en MEM. |
| 01 | Resultado final de WB. |

ForwardAE controla el primer operando y ForwardBE el segundo. MEM tiene prioridad sobre WB porque su instrucción es más reciente. Las coincidencias con x0 se ignoran.

El dato de MEM debe ser ALUResultM para operaciones ALU o PCPlus4M para JAL. No conectar siempre ALUResultM: JAL necesita reenviar su dirección de retorno. El dato de WB debe ser ResultW, después de seleccionar ALU, memoria o PC+4.

Una carga en MEM todavía no se utiliza como fuente de forwarding en este diseño. Si coincide con el registro solicitado, tampoco se selecciona un valor más antiguo de WB para ese mismo registro. La pausa Load-Use debe haber impedido que una instrucción dependiente entre a EX demasiado pronto; esta condición por sí sola no introduce una pausa adicional en EX.

## Load-Use

Si una carga en EX escribe un registro distinto de x0 que la instrucción en ID necesita leer, StallF y StallD valen 1 y FlushE vale 1. FlushD permanece en 0 para conservar la instrucción que está esperando.

El PC y el registro IF/ID deben conservarse. El control y los datos que entran a EX deben limpiarse para insertar una burbuja. Las instrucciones que ya estaban en EX, MEM y WB siguen avanzando.

Con memorias como las de la base, se espera una pausa de un ciclo. Cuando la instrucción dependiente llegue a EX, la carga estará en WB y se podrá seleccionar su dato con forwarding. No se implementan esperas variables de memoria ni pausas globales.

## Saltos

Si PCSrcE vale 1, FlushD y FlushE valen 1. StallF y StallD valen 0 aunque coincida una condición de Load-Use. Así el PC puede recibir el destino del salto.

FlushE limpia tanto el control de EX en el controller como el registro ID/EX del datapath. FlushD limpia IF/ID. La limpieza debe tener prioridad sobre conservar esos registros. El flush elimina las instrucciones jóvenes; no debe borrar el salto que avanza de EX a MEM ni las instrucciones anteriores.

## Conexiones en el datapath

Implementadas en `datapath_pipeline.v`:

1. Registros IF/ID (StallD, FlushD), ID/EX (FlushE), EX/MEM y MEM/WB. StallF conserva el PC.
2. Multiplexores de forwarding en EX; el de rs2 va antes del multiplexor de ALUSrcE.
3. El dato del SW es el segundo operando ya corregido por forwarding.
4. BEQ compara los operandos ya corregidos.
5. PC+4 llega hasta WB; desde MEM se reenvía PCPlus4M si la instrucción es JAL.
6. El banco de registros escribe en el flanco de bajada, así ID lee en el mismo ciclo el dato que escribe WB.
7. Si la instrucción no usa rs1 o rs2 (tipo I y J), ese campo pasa a EX como x0 para evitar forwarding innecesario.

## Prueba

La prueba aislada solo necesita hazard_unit.v y testbench_hazard.v. En Vivado, seleccionar testbench_hazard como módulo principal de simulación y ejecutar hasta el final.

Resultado esperado: `Hazard Unit: 33 casos correctos`.

Los casos cubren forwarding desde MEM y WB, prioridad entre productores, exclusión de cargas en MEM y x0, Load-Use, uso real de registros fuente, dependencia del dato de SW, saltos y liberación de las pausas. La prueba comprueba señales de control; no ejecuta programas Assembly ni sustituye los cuatro programas de E1.

Verificado el 2 de noviembre de 2026 con Vivado Simulator 2025.2: 33 casos correctos. Después se conectó esta unidad dentro del controller existente y se verificaron 18 condiciones en su testbench actualizado. Estas pruebas no comprueban todavía el datapath ni el procesador completo.

Para repetir la prueba desde una consola con las herramientas de Vivado disponibles, ejecutar dentro de Pipeline_E1:

```text
xvlog --work work hazard_unit.v testbench_hazard.v
xelab --timescale 1ns/1ps --debug typical --snapshot hazard_test work.testbench_hazard
xsim hazard_test --runall
```

La opción de escala de tiempo evita mezclar módulos sin escala declarada con el testbench de 1ns/1ps. En la comprobación realizada se guardaron los archivos generados fuera de las fuentes, en `../tmp/hazard_sim`.

Evidencias guardadas en el equipo de desarrollo, no incluidas en este repositorio:

- `../tmp/hazard_sim/hazard_sim.log`: resultado de los 33 casos.
- `../tmp/hazard_sim/hazard.vcd`: formas de onda de las señales de la prueba.
- `../tmp/hazard_sim/run_hazard.tcl`: órdenes utilizadas para guardar las formas de onda.
- `../tmp/hazard_sim/controller_sim.log`: resultado anterior de la prueba aislada del controller.
- `../tmp/control_hazard_sim/control_hazard_sim.log`: resultado actual de las 18 comprobaciones de la conexión.
- `../tmp/control_hazard_sim/control_hazard.vcd`: formas de onda de la prueba conjunta.
