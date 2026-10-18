# Roda um programa de teste e mostra o resultado no Transcript. Uso (pasta sim/):
#   do teste.do                 lista os programas da pasta de testes
#   do teste.do ula             roda <pasta de testes>/ula.asm
#   do teste.do C:/x/prog.asm   roda um .asm ou .mif em qualquer caminho
# A pasta de testes padrao pode ser trocada com: set PASTA_TESTES C:/outra/pasta

if {![info exists PASTA_TESTES]} { set PASTA_TESTES "../mips - alunos - 2026.2" }

if {$argc == 0} {
    echo "Programas em $PASTA_TESTES:"
    foreach f [lsort [glob -nocomplain -directory $PASTA_TESTES *.asm *.mif]] {
        echo "   do teste.do [file rootname [file tail $f]]"
    }
    return
}

set teste_arq ""
foreach c [list $1 "$PASTA_TESTES/$1" "$PASTA_TESTES/$1.asm" "$PASTA_TESTES/$1.mif"] {
    if {[file isfile $c]} { set teste_arq $c; break }
}
if {$teste_arq eq ""} {
    echo "Programa '$1' nao encontrado (procurei tambem em $PASTA_TESTES)."
    return
}

# --- Converte para instrucoes.mif (via cmd, que resolve o python/py do Windows) ---
set convertido 0
foreach py {python py} {
    if {![catch {exec cmd /c $py ../testes/asm_para_mif.py $teste_arq instrucoes.mif} saida]} {
        set convertido 1
        break
    }
}
if {!$convertido} {
    echo "Falha ao converter $teste_arq (o Python 3 precisa estar instalado):"
    echo $saida
    return
}
regexp {fim=(\d+)} $saida -> teste_fim

# --- Compila, abre a simulacao e monta a onda (sem rodar) ---
set modo_teste 1
do run.do
unset modo_teste

# --- Executa ciclo a ciclo ate o fim do programa, uma excecao ou um laco ---
run 25 ns
set ciclos 0
set pc_ant -1
set excecao ""
set motivo "limite de 3000 ciclos atingido"
while {$ciclos < 3000} {
    run 20 ns
    incr ciclos
    set st [examine sim:/CPU/uc/state]
    if {[string match EXCEPTION_OPCODE $st]}   { set excecao "opcode/funct inexistente" }
    if {[string match EXCEPTION_OVERFLOW $st]} { set excecao "overflow" }
    if {[string match EXCEPTION_ZERO $st]}     { set excecao "divisao por zero" }
    if {$st eq "FETCH_1"} {
        set pc [examine -radix unsigned sim:/CPU/datapath/pc_out]
        if {$excecao ne ""} { set motivo "excecao: $excecao"; break }
        if {$pc >= $teste_fim} { set motivo "fim do programa"; break }
        if {$pc == $pc_ant} { set motivo "laco infinito no endereco $pc"; break }
        set pc_ant $pc
    }
}
catch {wave zoom full}

# --- Resumo ---
echo ""
echo "=== [file tail $teste_arq]: $motivo apos $ciclos ciclos ($now ps)"
echo "    PC=[examine -radix unsigned sim:/CPU/datapath/pc_out]  EPC=[examine -radix unsigned sim:/CPU/datapath/EPC_out]  HI=[examine -radix decimal sim:/CPU/datapath/hi_out]  LO=[examine -radix decimal sim:/CPU/datapath/lo_out]"
for {set r 1} {$r < 32} {incr r} {
    set v [examine -radix decimal sim:/CPU/datapath/Registradores/Cluster($r)]
    if {$v != 0} {
        echo [format "    \$%-2d = %-12s (0x%s)" $r $v [examine -radix hex sim:/CPU/datapath/Registradores/Cluster($r)]]
    }
}
echo "    (registradores nao listados valem 0)"
