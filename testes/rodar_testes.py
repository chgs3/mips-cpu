"""Suíte de testes da CPU. Uso: python rodar_testes.py [filtro ...]"""
import sys

from harness import compilar, executar

M = lambda x: x & 0xFFFFFFFF

# Rotinas de tratamento de exceção: cada uma grava um marcador e fica em laço.
# Os bytes 253/254/255 guardam o endereço da rotina (opcode / overflow / div por zero).
ROTINAS = """
.org 100
t_op: addi $20, $0, 253
t_op_fim: j t_op_fim
.org 120
t_ov: addi $21, $0, 254
t_ov_fim: j t_ov_fim
.org 140
t_dz: addi $22, $0, 255
t_dz_fim: j t_dz_fim
.org 253
.byte 100
.byte 120
.byte 140
"""

TESTES = [
    ("ALU / imediatos / shifts", """
addi $1, $0, 7
addi $2, $0, -3
add  $3, $1, $2
sub  $4, $1, $2
and  $5, $1, $2
slt  $6, $2, $1
slt  $7, $1, $2
lui  $8, 0x1234
sll  $9, $1, 4
addi $10, $0, -16
sra  $11, $10, 2
sll  $12, $2, 1
sra  $13, $1, 1
fim: j fim
""", {"R1": 7, "R2": M(-3), "R3": 4, "R4": 10, "R5": 5, "R6": 1, "R7": 0,
      "R8": 0x12340000, "R9": 112, "R10": M(-16), "R11": M(-4), "R12": M(-6), "R13": 3}, 300),

    ("slt com negativos e iguais, sra 31, shift de 0", """
addi $1, $0, -5
addi $2, $0, -2
slt  $3, $1, $2
slt  $4, $2, $1
slt  $5, $1, $1
lui  $6, 0x8000
sra  $7, $6, 31
sll  $8, $1, 0
sra  $9, $2, 0
fim: j fim
""", {"R3": 1, "R4": 0, "R5": 0, "R7": M(-1), "R8": M(-5), "R9": M(-2)}, 300),

    ("Memória: lw / sw / lb / sb", """
addi $1, $0, 200
lui  $2, 0x1122
addi $2, $2, 0x3344
sw   $2, 0($1)
lw   $3, 0($1)
lb   $4, 1($1)
addi $5, $0, 0xAB
sb   $5, 2($1)
lw   $6, 0($1)
addi $7, $0, -1
sb   $7, 4($1)
lb   $8, 4($1)
lw   $9, 4($1)
lw   $10, -200($1)
fim: j fim
""", {"R3": 0x11223344, "R4": 0x33, "R6": 0x11AB3344, "R8": 0xFF, "R9": 0xFF,
      "R10": 0x200100C8}, 400),

    ("sb / lb nos 4 bytes da palavra", """
addi $1, $0, 208
addi $2, $0, 0x11
addi $3, $0, 0x22
addi $4, $0, 0x33
addi $5, $0, 0x44
sb   $2, 0($1)
sb   $3, 1($1)
sb   $4, 2($1)
sb   $5, 3($1)
lw   $6, 0($1)
lb   $7, 3($1)
lb   $8, 0($1)
fim: j fim
""", {"R6": 0x44332211, "R7": 0x44, "R8": 0x11}, 400),

    ("Desvios: beq / bne / j / jal / jr", """
addi $1, $0, 5
addi $2, $0, 5
beq  $1, $2, L1
addi $10, $0, 1
L1: bne $1, $2, L2
addi $11, $0, 2
L2: addi $3, $0, 9
bne  $1, $3, L3
addi $12, $0, 3
L3: beq $1, $3, L4
addi $13, $0, 4
L4: jal F
addi $14, $0, 5
addi $20, $0, 3
laco: addi $21, $21, 1
addi $20, $20, -1
bne  $20, $0, laco
j FIM
addi $15, $0, 6
F: addi $16, $0, 7
jr $31
FIM: j FIM
""", {"R10": 0, "R11": 2, "R12": 0, "R13": 4, "R14": 5, "R15": 0, "R16": 7,
      "R31": 48, "R20": 0, "R21": 3}, 600),

    ("Exemplo da especificação: beq com offset 3", """
addi $3, $0, 0x3a
addi $4, $0, 0x3a
beq  $3, $4, 3
addi $10, $0, 1
addi $11, $0, 1
addi $12, $0, 1
addi $13, $0, 7
fim: j fim
""", {"R10": 0, "R11": 0, "R12": 0, "R13": 7}, 200),

    ("mult / div / mfhi / mflo", """
addi $1, $0, -7
addi $2, $0, 3
mult $1, $2
mfhi $3
mflo $4
div  $1, $2
mfhi $5
mflo $6
lui  $8, 1
mult $8, $8
mfhi $9
mflo $10
addi $11, $0, 100
addi $12, $0, -9
div  $11, $12
mflo $13
mfhi $14
lui  $15, 0x7FFF
addi $15, $15, 0x7FFF
mult $15, $15
mfhi $16
mflo $17
fim: j fim
""", {"R3": M(-1), "R4": M(-21), "R5": M(-1), "R6": M(-2), "R9": 1, "R10": 0,
      "R13": M(-11), "R14": 1,
      "R16": ((0x7FFF7FFF * 0x7FFF7FFF) >> 32) & 0xFFFFFFFF,
      "R17": (0x7FFF7FFF * 0x7FFF7FFF) & 0xFFFFFFFF}, 1200),

    ("Pilha: push / pop e SP inicial", """
addi $1, $0, 11
addi $2, $0, 22
push $1
push $2
pop  $3
pop  $4
fim: j fim
""", {"R3": 22, "R4": 11, "R29": 227}, 400),

    ("Chamada aninhada salvando $31 na pilha", """
jal  f1
addi $10, $0, 10
fim: j fim
f1: push $31
jal  f2
addi $11, $0, 11
pop  $31
jr   $31
f2: addi $12, $0, 12
jr   $31
""", {"R10": 10, "R11": 11, "R12": 12, "R29": 227, "R31": 4}, 300),

    ("Exceção: opcode inexistente", """
addi $1, $0, 1
.word 0xFC000000
addi $2, $0, 2
""" + ROTINAS, {"R1": 1, "R2": 0, "R20": 253, "EPC": 4}, 200),

    ("Exceção: funct inexistente (tipo R)", """
addi $1, $0, 1
.word 0x0000003F
addi $2, $0, 2
""" + ROTINAS, {"R1": 1, "R2": 0, "R20": 253, "EPC": 4}, 200),

    ("Exceção: overflow (add)", """
lui  $1, 0x7FFF
addi $1, $1, 0x7FFF
add  $2, $1, $1
addi $3, $0, 3
""" + ROTINAS, {"R2": 0, "R3": 0, "R21": 254, "EPC": 8}, 200),

    ("Exceção: overflow (sub)", """
lui  $1, 0x8000
addi $2, $0, 1
sub  $3, $1, $2
addi $4, $0, 4
""" + ROTINAS, {"R3": 0, "R4": 0, "R21": 254, "EPC": 8}, 200),

    ("Exceção: overflow (addi)", """
lui  $1, 0x7FFF
addi $1, $1, 0x7FFF
addi $1, $1, 0x7FFF
addi $2, $1, 2
addi $3, $0, 3
""" + ROTINAS, {"R1": 0x7FFFFFFE, "R2": 0, "R3": 0, "R21": 254, "EPC": 12}, 200),

    ("Exceção: divisão por zero", """
addi $1, $0, 5
div  $1, $0
addi $2, $0, 2
""" + ROTINAS, {"R2": 0, "R22": 255, "EPC": 4}, 300),
]


def ciclos_mult():
    _, estados = executar("Ciclos do mult (limite da especificação: 40)", """
addi $1, $0, -7
addi $2, $0, 3
mult $1, $2
fim: j fim
""", {"R1": M(-7)}, 80, rastrear=True)
    n = estados.count("ESPERA_MD")
    print(f"   multiplicador ocupado por {n} ciclos (MUL_1..SALVA_MD = {n + 3})")
    return n <= 40


if __name__ == "__main__":
    compilar()
    filtros = [f.lower() for f in sys.argv[1:]]
    resultados = []
    for nome, fonte, esperado, ciclos in TESTES:
        if filtros and not any(f in nome.lower() for f in filtros):
            continue
        resultados.append(executar(nome, fonte, esperado, ciclos)[0])
    if not filtros:
        resultados.append(ciclos_mult())
    print(f"\n{sum(resultados)}/{len(resultados)} testes passaram")
    sys.exit(0 if all(resultados) else 1)
