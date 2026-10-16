"""Gera sim/instrucoes.mif com o programa de demonstração (23 instruções) e confere o resultado."""
import os

from harness import AQUI, compilar, executar, gravar_mif

M = lambda x: x & 0xFFFFFFFF

PROGRAMA = """
addi $1, $0, 7
addi $2, $0, -3
add  $3, $1, $2
sub  $4, $1, $2
and  $5, $1, $2
slt  $6, $2, $1
lui  $7, 0x1234
sll  $8, $1, 4
sra  $9, $2, 1
addi $10, $0, 200
sw   $7, 0($10)
lw   $11, 0($10)
addi $12, $0, 0x55
sb   $12, 1($10)
lb   $13, 1($10)
lw   $14, 0($10)
mult $1, $2
mfhi $15
mflo $16
div  $4, $1
mfhi $17
mflo $18
push $1
pop  $19
beq  $1, $19, ok1
addi $20, $0, 99
ok1: bne $1, $2, ok2
addi $20, $0, 98
ok2: jal func
j    fim
func: addi $21, $0, 21
jr   $31
fim: j fim
"""

ESPERADO = {"R3": 4, "R4": 10, "R5": 5, "R6": 1, "R7": 0x12340000, "R8": 112, "R9": M(-2),
            "R11": 0x12340000, "R13": 0x55, "R14": 0x12345500, "R15": M(-1), "R16": M(-21),
            "R17": 3, "R18": 1, "R19": 7, "R20": 0, "R21": 21, "R29": 227, "R31": 116}

if __name__ == "__main__":
    compilar()
    executar("Programa de demonstração", PROGRAMA, ESPERADO, 400)
    destino = os.path.normpath(os.path.join(AQUI, "..", "sim", "instrucoes.mif"))
    gravar_mif(PROGRAMA, destino, comentado=True)
    print("gravado em", destino)
