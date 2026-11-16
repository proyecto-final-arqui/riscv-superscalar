.text
.globl _start
_start:
    addi x1, x0, 0            # i = 0
    addi x2, x0, 10           # n = 10
    addi x3, x0, 0            # suma = 0
    addi x5, x0, 0            # direccion = 0
LOOP:
    beq  x1, x2, END          # sale cuando i == n
    sw   x1, 0(x5)            # mem[4i] = i
    add  x3, x3, x1           # suma += i
    addi x1, x1, 1            # i++
    addi x5, x5, 4            # direccion += 4
    jal  x0, LOOP             # vuelve al bucle
END:
    sw   x3, 60(x0)           # mem[60] = 45
    lw   x6, 60(x0)           # x6 = 45
    add  x7, x6, x1           # x7 = 55
