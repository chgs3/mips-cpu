# Compila e simula a CPU. Uso, no Transcript do ModelSim (pasta sim/): do run.do
# Para mudar so o programa: edite instrucoes.mif e rode "do run.do" de novo.

# Encerra a simulacao anterior, se houver (descarta tambem ondas criadas no Wave Editor)
catch {quit -sim}

# --- Compilacao (VHDL fornecido -> Verilog -> SystemVerilog) ---
if {![file exists work]} { vlib work }
vcom -quiet ../rtl/fornecidos/Registrador.vhd ../rtl/fornecidos/Instr_Reg.vhd ../rtl/fornecidos/Banco_reg.vhd ../rtl/fornecidos/RegDesloc.vhd ../rtl/fornecidos/ula32.vhd ../rtl/fornecidos/Memoria.vhd
vlog -quiet ../rtl/datapath/mux/*.v ../rtl/datapath/util/*.v ../rtl/multdiv/MultDiv.v ../rtl/datapath/Datapath.v ../rtl/CPU.v
vlog -quiet -sv ../rtl/controle/UnidadeControle.sv

# --- Simulacao ---
vsim -voptargs=+acc work.CPU

# Clock de 20 ns (bordas de subida em 10, 30, 50 ns...) e reset ativo ate 25 ns
force -freeze sim:/CPU/clk 0 0, 1 {10 ns} -r {20 ns}
force -freeze sim:/CPU/reset 1 0, 0 {25 ns}

# --- Sinais exigidos pela especificacao (secao 3.2.7) + depuracao ---
add wave -divider "Controle"
add wave -label clk   sim:/CPU/clk
add wave -label reset sim:/CPU/reset
add wave -label estado sim:/CPU/uc/state

add wave -divider "Registradores especiais"
add wave -label PC  -radix unsigned sim:/CPU/datapath/pc_out
add wave -label EPC -radix unsigned sim:/CPU/datapath/EPC_out
add wave -label MDR -radix decimal  sim:/CPU/datapath/mem_data_reg_out
add wave -label IR_31_26 -radix hex sim:/CPU/datapath/IR_31_26
add wave -label IR_25_21 -radix unsigned sim:/CPU/datapath/IR_25_21
add wave -label IR_20_16 -radix unsigned sim:/CPU/datapath/IR_20_16
add wave -label IR_15_0  -radix hex sim:/CPU/datapath/IR_15_0

add wave -divider "Banco de registradores"
add wave -label R29 -radix unsigned sim:/CPU/datapath/Registradores/Cluster(29)
add wave -label R31 -radix unsigned sim:/CPU/datapath/Registradores/Cluster(31)
add wave -label Registradores -radix decimal sim:/CPU/datapath/Registradores/Cluster
add wave -label HI -radix decimal sim:/CPU/datapath/hi_out
add wave -label LO -radix decimal sim:/CPU/datapath/lo_out

add wave -divider "Memoria / ALU"
add wave -label Endereco  -radix unsigned sim:/CPU/datapath/mux_ad_mem_out
add wave -label Wr        sim:/CPU/Wr
add wave -label DadoEscrita -radix decimal sim:/CPU/datapath/mux_mem_write_out
add wave -label MemSaida  -radix decimal sim:/CPU/datapath/memory_out
add wave -label ALUOut    -radix decimal sim:/CPU/datapath/ALUout_out

# O teste.do reaproveita este script e controla a execucao por conta propria
if {![info exists modo_teste]} {
    run 6000 ns
    catch {wave zoom full}
}
