# MIPS-cpu — Projeto IF674 (2026.2)

CPU MIPS multiciclo descrita em Verilog/SystemVerilog sobre os componentes VHDL fornecidos pela disciplina.

## Estrutura

```
rtl/
  CPU.v                      Top-level: liga Datapath + UnidadeControle
  datapath/
    Datapath.v               Unidade de processamento (instancia todos os blocos abaixo)
    mux/                     Multiplexadores do datapath
    util/                    Extensores de sinal/zero, shifts fixos e lógica de store byte
  controle/
    UnidadeControle.sv       FSM da unidade de controle
  multdiv/
    MultDiv.v                Multiplicador (Booth) e divisor
  fornecidos/                Componentes VHDL da disciplina — NÃO alterar
    Banco_reg.vhd  Instr_Reg.vhd  Memoria.vhd  RegDesloc.vhd  Registrador.vhd  ula32.vhd
sim/
  run.do                     Script do ModelSim: compila, aplica clock/reset, monta a onda e roda
  teste.do                   Roda um programa (.asm/.mif) até o fim e lista os registradores no Transcript
  instrucoes.mif             Programa carregado pela Memoria (nome fixo em Memoria.vhd)
  TESTE.mif
testes/
  rodar_testes.py            Suíte automática: monta programas, simula e confere os registradores
  gerar_demo.py              Regenera sim/instrucoes.mif com o programa de demonstração
  asm_para_mif.py            Converte um programa .asm em sim/instrucoes.mif
  harness.py                 Montador MIPS mínimo + execução do ModelSim em modo texto
```

## Simulação (ModelSim)

`Memoria.vhd` lê `instrucoes.mif` a partir do diretório de trabalho do simulador.
Crie o projeto do ModelSim (`.mpf`) dentro de `sim/` ou copie o `.mif` para o diretório do projeto.

Com o ModelSim aberto em `sim/`, digite no Transcript: `do run.do`.

Para rodar um programa de teste e ver o resultado no Transcript:

```
do teste.do                  # lista os programas da pasta de testes
do teste.do ula              # converte e roda ula.asm até o fim, uma exceção ou um laço
do teste.do C:/x/prog.mif    # também aceita .asm/.mif em qualquer caminho
```

O `teste.do` sobrescreve `sim/instrucoes.mif`; para voltar ao programa de demonstração,
rode `python testes/gerar_demo.py`.

Ordem de compilação sugerida:

1. `rtl/fornecidos/*.vhd`
2. `rtl/datapath/util/*.v` e `rtl/datapath/mux/*.v`
3. `rtl/multdiv/MultDiv.v`
4. `rtl/datapath/Datapath.v`
5. `rtl/controle/UnidadeControle.sv` (SystemVerilog)
6. `rtl/CPU.v`

Para gerar `.mif` a partir de assembly MIPS: https://jotaveesse.github.io/Mips-to-Mif/

## Testes automáticos

Requer Python 3 e o ModelSim instalado (o `vsim` é procurado no PATH, em `C:/intelFPGA/20.1/...`
ou na variável de ambiente `VSIM`).

```
cd testes
python rodar_testes.py          # todos os testes
python rodar_testes.py pilha    # só os testes com "pilha" no nome
python gerar_demo.py            # regrava sim/instrucoes.mif com o programa de demonstração
python asm_para_mif.py prog.asm # converte prog.asm e grava em sim/instrucoes.mif
```
