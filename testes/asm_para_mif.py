"""Converte um programa .asm (ou copia um .mif pronto) para a memória da CPU.

Uso: python asm_para_mif.py programa.asm|programa.mif [saida.mif]
Sem o segundo argumento, grava em sim/instrucoes.mif.
Imprime "fim=N": o endereço logo após a última instrução do programa principal.
"""
import os
import re
import shutil
import sys

from harness import AQUI, gravar_mif


def fim_do_asm(fonte):
    """Endereço após a última instrução antes do primeiro `.org`."""
    n = 0
    for ln in (l.split("#")[0].strip() for l in fonte.splitlines()):
        if ln.startswith(".org"):
            break
        ln = re.sub(r"^\w+:\s*", "", ln)
        if ln and not ln.startswith(".byte"):
            n += 1
    return 4 * n


def fim_do_mif(texto):
    """Endereço após a última palavra não nula abaixo dos vetores de exceção (253)."""
    base = 2 if re.search(r"DATA_RADIX\s*=\s*BIN", texto, re.I) else 16
    ultimo = -1
    for end, val in re.findall(r"^\s*(\d+)\s*:\s*([0-9A-Fa-f]+)\s*;", texto, re.M):
        if int(end) < 253 and int(val, base) != 0:
            ultimo = max(ultimo, int(end))
    return (ultimo // 4 + 1) * 4 if ultimo >= 0 else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    origem = sys.argv[1]
    destino = sys.argv[2] if len(sys.argv) > 2 else os.path.join(AQUI, "..", "sim", "instrucoes.mif")
    with open(origem, encoding="utf-8") as f:
        texto = f.read()
    if origem.lower().endswith(".mif"):
        if os.path.abspath(origem) != os.path.abspath(destino):
            shutil.copyfile(origem, destino)
        fim = fim_do_mif(texto)
    else:
        gravar_mif(texto, destino)
        fim = fim_do_asm(texto)
    print("gravado em", os.path.normpath(destino))
    print(f"fim={fim}")
