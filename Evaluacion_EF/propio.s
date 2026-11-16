# Programa propio de evaluacion: procesamiento de un arreglo de 8 enteros.
# x1 = 1024 es la direccion base de datos. x31 = 1 se usa en las
# comparaciones de los bucles (slt deja 1 mientras hay que seguir).
#
# Etapa 1: inicializa A[i] = (13 * (i + 1)) mod 32 sin multiplicar.
# Etapa 2: suma, maximo y cantidad de elementos mayores que 10.
#          Tiene saltos que dependen del dato (dificiles de predecir).
# Etapa 3: Fibonacci F(0..11) en memoria. Cadena de dependencias RAW.
# Etapa 4: ordena A con burbuja. Bucles anidados, Load-Use y saltos.
.text
.globl _start
_start:
etapa_1:
    addi x31, x0, 1         # constante 1
    addi x1, x0, 1024       # base del arreglo A
    addi x2, x0, 8          # n = 8
    addi x3, x0, 0          # i
    addi x4, x0, 0          # valor
    add  x5, x1, x0         # puntero a A[i]
I1:
    addi x4, x4, 13         # valor += 13
    andi x4, x4, 31         # valor mod 32
    sw   x4, 0(x5)          # A[i] = valor
    addi x5, x5, 4
    addi x3, x3, 1
    slt  x6, x3, x2         # i < n ?
    beq  x6, x31, I1        # salto de vuelta: se toma 7 veces
    sw   x3, 48(x1)         # elementos generados = 8
etapa_2:
    addi x3, x0, 0          # i
    add  x5, x1, x0         # puntero
    addi x8, x0, 0          # suma
    addi x9, x0, 0          # maximo
    addi x10, x0, 0         # cantidad de elementos > 10
    addi x11, x0, 10        # umbral
S1:
    lw   x12, 0(x5)         # v = A[i]
    add  x8, x8, x12        # suma += v (Load-Use)
    slt  x6, x9, x12        # maximo < v ?
    beq  x6, x0, S2         # depende del dato
    add  x9, x12, x0        # maximo = v
S2:
    slt  x6, x11, x12       # 10 < v ?
    beq  x6, x0, S3         # depende del dato
    addi x10, x10, 1
S3:
    addi x5, x5, 4
    addi x3, x3, 1
    slt  x6, x3, x2
    beq  x6, x31, S1        # salto de vuelta
    sw   x8, 32(x1)         # suma = 116
    sw   x9, 36(x1)         # maximo = 27
    sw   x10, 40(x1)        # cantidad > 10 = 5
etapa_3:
    addi x13, x0, 0         # F(i-2)
    addi x14, x0, 1         # F(i-1)
    addi x5, x1, 64         # puntero a F
    sw   x13, 0(x5)         # F(0) = 0
    sw   x14, 4(x5)         # F(1) = 1
    addi x3, x0, 2          # i
    addi x15, x0, 12        # cantidad de terminos
F1:
    add  x16, x13, x14      # F(i) = F(i-2) + F(i-1)
    add  x13, x14, x0
    add  x14, x16, x0
    sw   x16, 8(x5)
    addi x5, x5, 4
    addi x3, x3, 1
    slt  x6, x3, x15
    beq  x6, x31, F1        # salto de vuelta: se toma 9 veces
    sw   x16, 44(x1)        # F(11) = 89
etapa_4:
    addi x17, x0, 0         # pasada
    addi x18, x0, 7         # n - 1
B1:
    add  x5, x1, x0         # puntero
    addi x3, x0, 0          # j
    sub  x19, x18, x17      # comparaciones de esta pasada
B2:
    lw   x20, 0(x5)         # A[j]
    lw   x21, 4(x5)         # A[j+1]
    slt  x6, x21, x20       # A[j+1] < A[j] ? (Load-Use)
    beq  x6, x0, B3         # depende del dato
    sw   x21, 0(x5)         # intercambio
    sw   x20, 4(x5)
B3:
    addi x5, x5, 4
    addi x3, x3, 1
    slt  x6, x3, x19
    beq  x6, x31, B2        # bucle interno
    addi x17, x17, 1
    slt  x6, x17, x18
    beq  x6, x31, B1        # bucle externo
    lw   x22, 0(x1)         # minimo = 1
    lw   x23, 28(x1)        # maximo = 27
fin:
    jal  x0, fin
