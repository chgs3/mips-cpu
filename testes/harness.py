"""Montador MIPS mínimo e execução da CPU no ModelSim em modo texto."""
import os
import re
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__)).replace("\\", "/")
RTL = os.path.normpath(os.path.join(AQUI, "..", "rtl")).replace("\\", "/")
RUN_DIR = f"{AQUI}/run"

CAMINHOS_VSIM = [
    "C:/intelFPGA/20.1/modelsim_ase/win32aloem/vsim.exe",
    "C:/intelFPGA_lite/20.1/modelsim_ase/win32aloem/vsim.exe",
    "E:/IntelFPGA/modelsim_ase/win32aloem/vsim.exe",
]


def localizar_vsim():
    if os.environ.get("VSIM"):
        return os.environ["VSIM"]
    no_path = shutil.which("vsim")
    if no_path:
        return no_path
    for c in CAMINHOS_VSIM:
        if os.path.exists(c):
            return c
    sys.exit("vsim não encontrado. Defina a variável de ambiente VSIM com o caminho do vsim.exe.")


VSIM = localizar_vsim()

R_FUNCT = {"add": 0x20, "and": 0x24, "sub": 0x22, "slt": 0x2a, "div": 0x1a, "mult": 0x18,
           "jr": 0x08, "mfhi": 0x10, "mflo": 0x12, "sll": 0x00, "sra": 0x03,
           "push": 0x05, "pop": 0x06}
I_OP = {"addi": 0x08, "beq": 0x04, "bne": 0x05, "lb": 0x20, "lui": 0x0f,
        "lw": 0x23, "sb": 0x28, "sw": 0x2b}
J_OP = {"j": 0x02, "jal": 0x03}


def _reg(t):
    return int(t.strip().lstrip("$"))


def _valor(t, rotulos, pc=None, desvio=False):
    t = t.strip()
    if t in rotulos:
        v = rotulos[t]
        return (v - (pc + 4)) // 4 if desvio else v
    return int(t, 0)


def montar(fonte):
    """Monta o assembly e devolve ({endereco: byte}, {rotulo: endereco}).

    Diretivas: `.org N` (posiciona), `.byte N` (um byte), `.word N` (uma palavra).
    Desvios aceitam rótulo ou offset numérico.
    """
    linhas = [l.split("#")[0].strip() for l in fonte.strip().splitlines()]
    linhas = [l for l in linhas if l]
    rotulos, pc, itens = {}, 0, []
    for ln in linhas:
        m = re.match(r"^\.org\s+(\S+)$", ln)
        if m:
            pc = int(m.group(1), 0)
            continue
        m = re.match(r"^(\w+):\s*(.*)$", ln)
        if m:
            rotulos[m.group(1)] = pc
            ln = m.group(2)
            if not ln:
                continue
        if re.match(r"^\.byte\s", ln):
            itens.append((pc, "byte", ln.split()[1]))
            pc += 1
            continue
        itens.append((pc, "ins", ln))
        pc += 4

    mem = {}
    for pc, tipo, ln in itens:
        if tipo == "byte":
            mem[pc] = _valor(ln, rotulos) & 0xFF
            continue
        op, *args = ln.replace(",", " ").split()
        if op == ".word":
            w = int(args[0], 0)
        elif op in R_FUNCT:
            rs = rt = rd = sh = 0
            if op in ("add", "and", "sub", "slt"):
                rd, rs, rt = map(_reg, args)
            elif op in ("div", "mult"):
                rs, rt = map(_reg, args)
            elif op in ("jr", "push"):
                rs = _reg(args[0])
            elif op in ("mfhi", "mflo", "pop"):
                rd = _reg(args[0])
            else:  # sll, sra
                rd, rt, sh = _reg(args[0]), _reg(args[1]), int(args[2], 0)
            w = (rs << 21) | (rt << 16) | (rd << 11) | (sh << 6) | R_FUNCT[op]
        elif op in I_OP:
            if op == "addi":
                rt, rs, v = _reg(args[0]), _reg(args[1]), _valor(args[2], rotulos)
            elif op in ("beq", "bne"):
                rs, rt, v = _reg(args[0]), _reg(args[1]), _valor(args[2], rotulos, pc, True)
            elif op == "lui":
                rt, rs, v = _reg(args[0]), 0, _valor(args[1], rotulos)
            else:  # lw, sw, lb, sb: rt, offset(rs)
                rt = _reg(args[0])
                m = re.match(r"^(.+)\((\$?\d+)\)$", args[1])
                v, rs = _valor(m.group(1), rotulos), _reg(m.group(2))
            w = (I_OP[op] << 26) | (rs << 21) | (rt << 16) | (v & 0xFFFF)
        elif op in J_OP:
            w = (J_OP[op] << 26) | ((_valor(args[0], rotulos) >> 2) & 0x3FFFFFF)
        else:
            raise ValueError(f"instrução desconhecida: {ln}")
        for i in range(4):
            mem[pc + i] = (w >> (8 * i)) & 0xFF
    return mem, rotulos


def gravar_mif(fonte, caminho, comentado=False):
    """Grava o programa em .mif (256 bytes, little-endian)."""
    mem, _ = montar(fonte)
    comentarios = {}
    if comentado:
        pc = 0
        for ln in (l.split("#")[0].strip() for l in fonte.strip().splitlines()):
            if not ln or ln.startswith("."):
                continue
            comentarios[pc] = ln
            pc += 4
    with open(caminho, "w", newline="\n") as f:
        f.write("DEPTH = 256;\nWIDTH = 8;\n\nADDRESS_RADIX = DEC;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n")
        ultimo = 255 if not comentado else max(mem)
        for a in range(ultimo + 1):
            c = f" --{comentarios[a]}" if a in comentarios else ""
            f.write(f"{a:03d} : {mem.get(a, 0):02X};{c}\n")
            if comentado and a % 4 == 3:
                f.write("\n")
        f.write("END;\n")


def compilar():
    os.makedirs(RUN_DIR, exist_ok=True)
    script = f"""vlib work
vcom -quiet {RTL}/fornecidos/Registrador.vhd {RTL}/fornecidos/Instr_Reg.vhd {RTL}/fornecidos/Banco_reg.vhd {RTL}/fornecidos/RegDesloc.vhd {RTL}/fornecidos/ula32.vhd {RTL}/fornecidos/Memoria.vhd
vlog -quiet {RTL}/datapath/mux/*.v {RTL}/datapath/util/*.v {RTL}/multdiv/MultDiv.v {RTL}/datapath/Datapath.v {RTL}/CPU.v
vlog -quiet -sv {RTL}/controle/UnidadeControle.sv
quit -f
"""
    with open(f"{RUN_DIR}/compile.do", "w") as f:
        f.write(script)
    saida = subprocess.run([VSIM, "-c", "-do", "compile.do"], cwd=RUN_DIR,
                           capture_output=True, text=True).stdout
    if any("Error" in l for l in saida.splitlines()):
        print(saida)
        sys.exit("Erro de compilação.")


def executar(nome, fonte, esperado, ciclos=300, rastrear=False):
    """Roda o programa por `ciclos` clocks e compara os valores finais.

    esperado: {"R<n>": valor, "EPC": valor, "PC": valor}
    """
    gravar_mif(fonte, f"{RUN_DIR}/instrucoes.mif")
    sondas = []
    for k in esperado:
        if k.startswith("R"):
            sondas.append((k, f"sim:/CPU/datapath/Registradores/Cluster({int(k[1:])})"))
        elif k == "PC":
            sondas.append((k, "sim:/CPU/datapath/pc_out"))
        elif k == "EPC":
            sondas.append((k, "sim:/CPU/datapath/EPC_out"))
    do = ["vsim -voptargs=+acc work.CPU",
          "force -freeze sim:/CPU/clk 0 0, 1 {10 ns} -r {20 ns}",
          "force -freeze sim:/CPU/reset 1 0, 0 {25 ns}",
          "run 25 ns"]
    if rastrear:
        do.append(f"for {{set i 0}} {{$i < {ciclos}}} {{incr i}} "
                  f"{{ run 20 ns; echo \"TRACE [examine sim:/CPU/uc/state]\" }}")
    else:
        do.append(f"run {ciclos * 20} ns")
    do += [f'echo "VAL {k} [examine -radix hex {p}]"' for k, p in sondas]
    do.append("quit -f")
    with open(f"{RUN_DIR}/t.do", "w") as f:
        f.write("\n".join(do) + "\n")
    saida = subprocess.run([VSIM, "-c", "-do", "t.do"], cwd=RUN_DIR,
                           capture_output=True, text=True).stdout

    obtido = dict(re.findall(r"^# VAL (\S+) (\S+)", saida, re.M))
    passou, detalhes = True, []
    for k, v in esperado.items():
        g = obtido.get(k, "?")
        ok = g != "?" and re.fullmatch(r"[0-9A-Fa-f]+", g) and int(g, 16) == (v & 0xFFFFFFFF)
        passou &= bool(ok)
        detalhes.append(f"   {'OK   ' if ok else 'FALHA'} {k:4s} esperado={v & 0xFFFFFFFF:#010x} obtido={g}")
    print(f"[{'PASSOU' if passou else 'FALHOU'}] {nome}")
    if not passou:
        print("\n".join(detalhes))
    estados = re.findall(r"^# TRACE (\S+)", saida, re.M)
    return passou, estados
