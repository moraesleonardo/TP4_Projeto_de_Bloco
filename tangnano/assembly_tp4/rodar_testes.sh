#!/bin/bash
# Monta, linka e executa (via qemu-aarch64) todos os programas Assembly do TP4,
# incluindo os 3 programas herdados do TP3 (mantidos para continuidade).
set -u
cd "$(dirname "$0")"
mkdir -p obj bin
OUT=/tmp/tp4_arm_results.txt
> "$OUT"

testar () {
    NOME=$1
    echo "===== $NOME =====" | tee -a "$OUT"
    aarch64-linux-gnu-as -g -o obj/${NOME}.o src/${NOME}.S >> "$OUT" 2>&1
    if [ $? -ne 0 ]; then echo "ERRO DE MONTAGEM" | tee -a "$OUT"; return; fi
    aarch64-linux-gnu-ld -o bin/${NOME} obj/${NOME}.o >> "$OUT" 2>&1
    if [ $? -ne 0 ]; then echo "ERRO DE LINKEDICAO" | tee -a "$OUT"; return; fi
    timeout 5 qemu-aarch64 ./bin/${NOME}
    CODIGO=$?
    if [ $CODIGO -eq 0 ]; then
        echo "RESULTADO: $NOME OK (codigo de saida 0)" | tee -a "$OUT"
    else
        echo "RESULTADO: $NOME FALHOU (codigo de saida $CODIGO)" | tee -a "$OUT"
    fi
    echo "" >> "$OUT"
}

echo "############################################" | tee -a "$OUT"
echo "Programas herdados do TP3 (reexecutados aqui para confirmar continuidade)" | tee -a "$OUT"
echo "############################################" | tee -a "$OUT"
testar loop_classificacao_tp3
testar parsing_comandos_tp3
testar gpio_acesso_tp3

echo "############################################" | tee -a "$OUT"
echo "Novos programas do TP4" | tee -a "$OUT"
echo "############################################" | tee -a "$OUT"
testar multipalavra_tp4
testar conversao_tp4
testar lookup_table_tp4
testar bitwise_tp4
testar neon_int_tp4
testar neon_float_tp4
testar comunicacao_fpga_tp4
testar medicao_desempenho_tp4

echo "===== gpio_fisico_tp4 (modo de teste, com --defsym MODO_TESTE=1) =====" | tee -a "$OUT"
aarch64-linux-gnu-as -g --defsym MODO_TESTE=1 -o obj/gpio_fisico_tp4_teste.o src/gpio_fisico_tp4.S >> "$OUT" 2>&1
aarch64-linux-gnu-ld -o bin/gpio_fisico_tp4_teste obj/gpio_fisico_tp4_teste.o >> "$OUT" 2>&1
rm -f gpio_mem_simulado.bin
timeout 5 qemu-aarch64 ./bin/gpio_fisico_tp4_teste
CODIGO=$?
if [ $CODIGO -eq 0 ]; then
    echo "RESULTADO: gpio_fisico_tp4 (modo de teste) OK (codigo de saida 0)" | tee -a "$OUT"
else
    echo "RESULTADO: gpio_fisico_tp4 (modo de teste) FALHOU (codigo de saida $CODIGO)" | tee -a "$OUT"
fi
echo "" >> "$OUT"

echo "===== gpio_fisico_tp4 (modo real, apenas verificando montagem p/ o Raspberry Pi) =====" | tee -a "$OUT"
aarch64-linux-gnu-as -g -o obj/gpio_fisico_tp4_real.o src/gpio_fisico_tp4.S >> "$OUT" 2>&1
aarch64-linux-gnu-ld -o bin/gpio_fisico_tp4_real obj/gpio_fisico_tp4_real.o >> "$OUT" 2>&1
if [ -f bin/gpio_fisico_tp4_real ]; then
    echo "RESULTADO: gpio_fisico_tp4 (modo real) monta e linka sem erros (execucao requer o Raspberry Pi fisico)" | tee -a "$OUT"
else
    echo "RESULTADO: gpio_fisico_tp4 (modo real) FALHOU NA MONTAGEM/LINKEDICAO" | tee -a "$OUT"
fi
echo "" >> "$OUT"

echo "===== telemetria_fpga_tp4 (modo de teste, com --defsym MODO_TESTE=1) =====" | tee -a "$OUT"
aarch64-linux-gnu-as -g --defsym MODO_TESTE=1 -o obj/telemetria_fpga_tp4_teste.o src/telemetria_fpga_tp4.S >> "$OUT" 2>&1
aarch64-linux-gnu-ld -o bin/telemetria_fpga_tp4_teste obj/telemetria_fpga_tp4_teste.o >> "$OUT" 2>&1
rm -f gpio_mem_simulado.bin
timeout 5 qemu-aarch64 ./bin/telemetria_fpga_tp4_teste
CODIGO=$?
if [ $CODIGO -eq 0 ]; then
    echo "RESULTADO: telemetria_fpga_tp4 (modo de teste) OK (codigo de saida 0)" | tee -a "$OUT"
else
    echo "RESULTADO: telemetria_fpga_tp4 (modo de teste) FALHOU (codigo de saida $CODIGO)" | tee -a "$OUT"
fi
echo "" >> "$OUT"

echo "===== telemetria_fpga_tp4 (modo real, apenas verificando montagem p/ o Raspberry Pi) =====" | tee -a "$OUT"
aarch64-linux-gnu-as -g -o obj/telemetria_fpga_tp4_real.o src/telemetria_fpga_tp4.S >> "$OUT" 2>&1
aarch64-linux-gnu-ld -o bin/telemetria_fpga_tp4_real obj/telemetria_fpga_tp4_real.o >> "$OUT" 2>&1
if [ -f bin/telemetria_fpga_tp4_real ]; then
    echo "RESULTADO: telemetria_fpga_tp4 (modo real) monta e linka sem erros (execucao requer o Raspberry Pi fisico)" | tee -a "$OUT"
else
    echo "RESULTADO: telemetria_fpga_tp4 (modo real) FALHOU NA MONTAGEM/LINKEDICAO" | tee -a "$OUT"
fi

echo "===== telemetria_serial_tp4 (modo de teste, com --defsym MODO_TESTE=1) =====" | tee -a "$OUT"
aarch64-linux-gnu-as -g --defsym MODO_TESTE=1 -o obj/telemetria_serial_tp4_teste.o src/telemetria_serial_tp4.S >> "$OUT" 2>&1
aarch64-linux-gnu-ld -o bin/telemetria_serial_tp4_teste obj/telemetria_serial_tp4_teste.o >> "$OUT" 2>&1
rm -f gpio_mem_simulado.bin
timeout 5 qemu-aarch64 ./bin/telemetria_serial_tp4_teste
CODIGO=$?
if [ $CODIGO -eq 0 ]; then
    echo "RESULTADO: telemetria_serial_tp4 (modo de teste) OK (codigo de saida 0)" | tee -a "$OUT"
else
    echo "RESULTADO: telemetria_serial_tp4 (modo de teste) FALHOU (codigo de saida $CODIGO)" | tee -a "$OUT"
fi
echo "" >> "$OUT"

echo "===== telemetria_serial_tp4 (modo real, apenas verificando montagem p/ o Raspberry Pi) =====" | tee -a "$OUT"
aarch64-linux-gnu-as -g -o obj/telemetria_serial_tp4_real.o src/telemetria_serial_tp4.S >> "$OUT" 2>&1
aarch64-linux-gnu-ld -o bin/telemetria_serial_tp4_real obj/telemetria_serial_tp4_real.o >> "$OUT" 2>&1
if [ -f bin/telemetria_serial_tp4_real ]; then
    echo "RESULTADO: telemetria_serial_tp4 (modo real) monta e linka sem erros (execucao requer o Raspberry Pi fisico)" | tee -a "$OUT"
else
    echo "RESULTADO: telemetria_serial_tp4 (modo real) FALHOU NA MONTAGEM/LINKEDICAO" | tee -a "$OUT"
fi

echo ""
echo "############################################"
echo "RESUMO FINAL"
echo "############################################"
grep -E "^RESULTADO:" "$OUT"
