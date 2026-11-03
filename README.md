# RISC-V Pipeline + Superescalar (Proyecto 2)

## Abrir el proyecto

Abrir `project_1.xpr` en Vivado.

## Correr un programa

1. En **Sources → Simulation Sources → sim_1**, clic derecho sobre el testbench
   (`testbench_program1` … `testbench_program4`) → **Set as Top**.
2. **Flow Navigator → Run Simulation → Run Behavioral Simulation**.
3. En la Tcl Console debe aparecer `PROGRAMA N (...): CORRECTO`.

## Cargar las ondas

Con la simulación abierta, en la Tcl Console:

```
source [get_property DIRECTORY [current_project]]/Pipeline_E1/ondas.tcl
ondas 2
```

Cambiar el `2` por el número del programa que se está simulando.
Las ondas se guardan como `Pipeline_E1/ondas_programN.wcfg`.

Si el primer comando falla, usar la ruta completa a `ondas.tcl`, por ejemplo:

```
source C:/Users/joacm/Documents/vivado/SingleCycle_26II/project_1/Pipeline_E1/ondas.tcl
```

## Programas

| Programa | Prueba |
|---|---|
| 1 | ISA sin dependencias |
| 2 | Forwarding |
| 3 | Stalling (Load-Use) |
| 4 | Flushing (saltos) |
