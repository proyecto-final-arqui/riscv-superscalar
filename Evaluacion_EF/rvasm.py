"""Ensamblador y modelo de referencia para el subconjunto RV32I del proyecto.

Uso:  python rvasm.py programa.s etapa_1 etapa_2 ... fin
  - Escribe programa.mem (una instruccion por linea, con comentarios).
  - Ejecuta el programa instruccion por instruccion hasta la etiqueta final
    y escribe programa_esperado.mem: por cada etapa, los 32 registros y 64
    palabras de memoria desde la base de datos (x1 al terminar la etapa A/1).
  - Imprime el PC final de cada etapa, el PC de la etiqueta final y el estado
    de cada etapa, para copiarlos al testbench.
La ultima instruccion de cada etapa es la que esta justo antes de la etiqueta
de la etapa siguiente; debe ejecutarse una sola vez.
"""
import re
import sys

NW = 64  # palabras de memoria comparadas por etapa
RTYPE = {'add': (0, 0), 'sub': (0x20, 0), 'slt': (0, 2), 'or': (0, 6), 'and': (0, 7)}
ITYPE = {'addi': 0, 'slti': 2, 'ori': 6, 'andi': 7}


def reg(s):
    s = s.strip()
    assert re.fullmatch(r'x([0-9]|[12][0-9]|3[01])', s), f"registro invalido: {s}"
    return int(s[1:])


def parse(path):
    """Devuelve la lista de instrucciones (texto, linea) y las etiquetas."""
    insts, labels = [], {}
    for n, raw in enumerate(open(path, encoding='utf-8'), 1):
        line = raw.split('#')[0].strip()
        while True:
            m = re.match(r'([A-Za-z_]\w*):\s*(.*)', line)
            if not m:
                break
            labels[m.group(1)] = 4 * len(insts)
            line = m.group(2).strip()
        if not line or line.startswith('.'):
            continue
        insts.append((line, n))
    return insts, labels


def split(text):
    op, _, rest = text.partition(' ')
    return op, [a.strip() for a in rest.split(',')] if rest else []


def encode(text, pc, labels):
    op, a = split(text)
    if op in RTYPE:
        f7, f3 = RTYPE[op]
        return f7 << 25 | reg(a[2]) << 20 | reg(a[1]) << 15 | f3 << 12 | reg(a[0]) << 7 | 0x33
    if op in ITYPE:
        imm = int(a[2], 0)
        assert -2048 <= imm < 2048, text
        return (imm & 0xfff) << 20 | reg(a[1]) << 15 | ITYPE[op] << 12 | reg(a[0]) << 7 | 0x13
    if op in ('lw', 'sw'):
        off, base = re.fullmatch(r'(-?\w+)\((x\d+)\)', a[1]).groups()
        off = int(off, 0) & 0xfff
        if op == 'lw':
            return off << 20 | reg(base) << 15 | 2 << 12 | reg(a[0]) << 7 | 0x03
        return (off >> 5) << 25 | reg(a[0]) << 20 | reg(base) << 15 | 2 << 12 | (off & 31) << 7 | 0x23
    if op == 'beq':
        o = labels[a[2]] - pc
        assert -4096 <= o < 4096
        o &= 0x1fff
        return ((o >> 12) & 1) << 31 | ((o >> 5) & 0x3f) << 25 | reg(a[1]) << 20 | reg(a[0]) << 15 | \
               ((o >> 1) & 0xf) << 8 | ((o >> 11) & 1) << 7 | 0x63
    if op == 'jal':
        o = (labels[a[1]] - pc) & 0x1fffff
        return ((o >> 20) & 1) << 31 | ((o >> 1) & 0x3ff) << 21 | ((o >> 11) & 1) << 20 | \
               ((o >> 12) & 0xff) << 12 | reg(a[0]) << 7 | 0x6f
    raise ValueError(f"instruccion no soportada: {text}")


def s32(v):
    v &= 0xffffffff
    return v - (1 << 32) if v >> 31 else v


def run(insts, labels, stop_pc, max_steps=100000):
    """Modelo de referencia: ejecuta hasta llegar a stop_pc."""
    x = [0] * 32
    mem = {}
    pc, steps, count = 0, 0, {}
    trace = []
    while pc != stop_pc:
        assert steps < max_steps, "el programa no llega a la etiqueta final"
        text = insts[pc // 4][0]
        op, a = split(text)
        count[pc] = count.get(pc, 0) + 1
        nxt = pc + 4
        if op in RTYPE:
            r1, r2 = x[reg(a[1])], x[reg(a[2])]
            v = {'add': r1 + r2, 'sub': r1 - r2, 'slt': int(s32(r1) < s32(r2)),
                 'or': r1 | r2, 'and': r1 & r2}[op]
            if reg(a[0]):
                x[reg(a[0])] = v & 0xffffffff
        elif op in ITYPE:
            r1, imm = x[reg(a[1])], int(a[2], 0)
            v = {'addi': r1 + imm, 'slti': int(s32(r1) < imm),
                 'ori': r1 | (imm & 0xffffffff), 'andi': r1 & (imm & 0xffffffff)}[op]
            if reg(a[0]):
                x[reg(a[0])] = v & 0xffffffff
        elif op in ('lw', 'sw'):
            off, base = re.fullmatch(r'(-?\w+)\((x\d+)\)', a[1]).groups()
            addr = (x[reg(base)] + int(off, 0)) & 0xffffffff
            assert addr % 4 == 0
            if op == 'lw':
                if reg(a[0]):
                    x[reg(a[0])] = mem.get(addr, 0)
            else:
                mem[addr] = x[reg(a[0])]
        elif op == 'beq':
            if x[reg(a[0])] == x[reg(a[1])]:
                nxt = labels[a[2]]
        elif op == 'jal':
            if reg(a[0]):
                x[reg(a[0])] = pc + 4
            nxt = labels[a[1]]
        trace.append((pc, list(x), dict(mem)))
        pc = nxt
        steps += 1
    return trace, count


def main():
    src, stages = sys.argv[1], sys.argv[2:]
    insts, labels = parse(src)
    base = src[:-2]
    words = [encode(t, 4 * i, labels) for i, (t, _) in enumerate(insts)]
    assert len(words) <= 128, "no entra en la memoria de instrucciones (128 palabras)"
    with open(base + '.mem', 'w', newline='\n') as f:
        for i, (w, (t, _)) in enumerate(zip(words, insts)):
            lab = [k for k, v in labels.items() if v == 4 * i]
            pre = (lab[-1] + ': ') if lab else ''
            f.write(f'{w:08x}  // {4 * i:3d}: {pre}{t}\n')

    fin = labels[stages[-1]]
    trace, count = run(insts, labels, fin)
    ends = [labels[s] - 4 for s in stages[1:]]
    for e in ends:
        assert count.get(e, 0) == 1, f"la instruccion en PC {e} no se ejecuta una sola vez"
    snaps = {}
    for pc, x, mem in trace:
        if pc in ends:
            snaps[pc] = (x, mem)
    basew = snaps[ends[0]][0][1] // 4
    with open(base + '_esperado.mem', 'w', newline='\n') as f:
        for k, e in enumerate(ends):
            x, mem = snaps[e]
            f.write(f'// etapa {stages[k]}: 32 registros\n')
            for r in range(32):
                f.write(f'{x[r]:08x}\n')
            f.write(f'// etapa {stages[k]}: memoria desde la palabra {basew}\n')
            for w in range(NW):
                f.write(f'{mem.get(4 * (basew + w), 0):08x}\n')

    print(f'{len(words)} instrucciones, {len(trace)} ejecutadas hasta {stages[-1]} (PC {fin})')
    print(f'base de datos: palabra {basew} (direccion {4 * basew})')
    for k, e in enumerate(ends):
        x, mem = snaps[e]
        regs = ', '.join(f'x{r}={s32(x[r])}' for r in range(1, 32) if x[r])
        mems = ', '.join(f'M[x1+{a - 4 * basew}]={s32(v)}' for a, v in sorted(mem.items()))
        print(f'{stages[k]}: termina en PC {e}\n  {regs}\n  {mems}')


if __name__ == '__main__':
    main()
