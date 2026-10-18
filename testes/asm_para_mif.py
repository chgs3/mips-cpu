"""Converte um programa .asm em .mif para a memória da CPU.

Uso: python asm_para_mif.py programa.asm [saida.mif]
Sem o segundo argumento, grava em sim/instrucoes.mif.
"""
import os
import sys

from harness import AQUI, gravar_mif

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    origem = sys.argv[1]
    destino = sys.argv[2] if len(sys.argv) > 2 else os.path.join(AQUI, "..", "sim", "instrucoes.mif")
    with open(origem, encoding="utf-8") as f:
        gravar_mif(f.read(), destino)
    print("gravado em", os.path.normpath(destino))
