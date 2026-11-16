.text
.globl _start
_start:
    # Fase 1: inicializacion de constantes e ILP inicial (ALU paralelas)
    addi x1, x0, 0          # base arreglo A = 0
    addi x2, x0, 64         # base arreglo B = 64
    addi x3, x0, 16         # N = 16 elementos
    addi x4, x0, 1          # constante 1
    addi x5, x0, 0          # indice i = 0
    addi x6, x0, 5          # semilla val = 5
    addi x7, x0, 25         # umbral = 25
    add  x8, x1, x0         # ptrA = 0
    add  x9, x2, x0         # ptrB = 64
    addi x10, x0, 0         # acumulador auxiliar

L1_init:
    sw   x6, 0(x8)          # A[i] = val
    addi x6, x6, 3          # val += 3 (en paralelo o inmediato)
    addi x8, x8, 4          # ptrA += 4
    addi x5, x5, 1          # i++
    andi x11, x6, 15        # mezcla bitwise independiente
    add  x10, x10, x11      # acumulador auxiliar
    slt  x12, x5, x3        # i < 16 ?
    beq  x12, x4, L1_init   # bucle predecible (15 tomadas, 1 no)

    # Fase 2: filtro y transformacion A -> B (load-use, mem, rama condicional)
    addi x5, x0, 0          # i = 0
    add  x8, x1, x0         # ptrA = 0
    add  x9, x2, x0         # ptrB = 64
    addi x13, x0, 0         # contador >= umbral

L2_proc:
    lw   x14, 0(x8)         # x14 = A[i]
    addi x8, x8, 4          # ptrA += 4 (evita stall si reordena o mide con stall)
    slt  x12, x14, x7       # A[i] < 25 ? (Load-Use posible segun emision)
    beq  x12, x4, L2_low    # primeras 7 tomadas, ultimas 9 no tomadas
    sub  x15, x14, x7       # x15 = A[i] - 25
    ori  x15, x15, 1        # fuerza bit 0
    addi x13, x13, 1        # count_high++
    jal  x0, L2_store
L2_low:
    addi x15, x14, 10       # B[i] = A[i] + 10
    addi x10, x10, 1        # marca rama baja
L2_store:
    sw   x15, 0(x9)         # B[i] = x15
    addi x9, x9, 4          # ptrB += 4
    addi x5, x5, 1          # i++
    slt  x12, x5, x3        # i < 16 ?
    beq  x12, x4, L2_proc   # bucle predecible

    # Fase 3: reduccion sobre B (8 iteraciones) con rama alternante (limite del BTB)
    addi x5, x0, 0          # i = 0
    addi x16, x0, 8         # M = 8 iteraciones
    add  x9, x2, x0         # ptrB = 64
    addi x17, x0, 0         # suma_B = 0
    addi x18, x0, 0         # suma_pares = 0
    addi x19, x0, 0         # toggle = 0 (alterna 0, 1, 0, 1...)

L3_red:
    lw   x20, 0(x9)         # x20 = B[i]
    addi x9, x9, 4          # ptrB += 4
    add  x17, x17, x20      # suma_B += B[i]
    sub  x19, x4, x19       # toggle = 1 - toggle
    beq  x19, x4, L3_odd    # alterna T / NT en cada iteracion
    sub  x18, x18, x20      # iteracion par: resta
    jal  x0, L3_next
L3_odd:
    add  x18, x18, x20      # iteracion impar: suma
L3_next:
    addi x5, x5, 1          # i++
    slt  x12, x5, x16       # i < 8 ?
    beq  x12, x4, L3_red

    # Cierre: guardar resumen en memoria
    add  x21, x17, x18      # checksum
    sw   x10, 128(x0)       # mem[128] = x10
    sw   x13, 132(x0)       # mem[132] = count_high
    sw   x17, 136(x0)       # mem[136] = suma_B
    sw   x18, 140(x0)       # mem[140] = suma_alt
    sw   x21, 144(x0)       # mem[144] = checksum
fin:
    jal  x0, fin
