#!/bin/bash
# Script de verificacao final - TP4
# Confere se todos os arquivos salvos localmente no notebook batem com a
# versao final e correta de cada um, antes de subir o repositorio pro GitHub.
#
# Uso: rode este script a partir de ~/projeto_bloco/TP4/
#   bash verificar_entrega_tp4.sh

BASE="$HOME/projeto_bloco/TP4"
ERROS=0

verificar() {
    local caminho="$1"
    local hash_esperado="$2"
    if [ ! -f "$caminho" ]; then
        echo "FALTANDO   $caminho"
        ERROS=$((ERROS+1))
        return
    fi
    local hash_real
    hash_real=$(md5sum "$caminho" | awk '{print $1}')
    if [ "$hash_real" == "$hash_esperado" ]; then
        echo "OK         $caminho"
    else
        echo "DESATUALIZADO  $caminho  (esperado $hash_esperado, encontrado $hash_real)"
        ERROS=$((ERROS+1))
    fi
}

echo "=== Verificando verilog_tp4/src/ ==="
verificar "$BASE/tangnano/verilog_tp4/src/bram_frame_buffer_tp4.v"        "6ea5e736ce4cbe222fc5d7ff951bd958"
verificar "$BASE/tangnano/verilog_tp4/src/camera_ov7670_capture_tp4.v"    "99be4deb33e85cb49b2edbe4aee37e45"
verificar "$BASE/tangnano/verilog_tp4/src/classificador_movimento_cfg.v" "4e001545d004ee765cfbf63a0f8b3900"
verificar "$BASE/tangnano/verilog_tp4/src/dsp_mac_tp4.v"                  "c93c258cd0b89e165eb939a82f314ef8"
verificar "$BASE/tangnano/verilog_tp4/src/estado_para_leds.v"             "4d56ad264b16e66e9ed800f4a3094eee"
verificar "$BASE/tangnano/verilog_tp4/src/frame_diff_tp4.v"               "e6344587b71f38c9713416172ebe0e29"
verificar "$BASE/tangnano/verilog_tp4/src/fsm_monitor_movimento_tp4.v"    "1350f55451d32584c851ab22ac133b8c"
verificar "$BASE/tangnano/verilog_tp4/src/sccb_master_tp4.v"              "17665f5017e5b30c90367b6bb1c03e04"
verificar "$BASE/tangnano/verilog_tp4/src/serial_out_tp4.v"               "e5359193246976d64e9d68cf413ce4d5"
verificar "$BASE/tangnano/verilog_tp4/src/top_tp4.v"                      "95d8a3791afa2ae3720f7fa7bb5c1845"
verificar "$BASE/tangnano/verilog_tp4/src/unidade_aritmetica_tp4.v"       "86b74b60a9180c0e36270a9aefb17140"

echo ""
echo "=== Verificando o arquivo de restricoes (.cst) ==="
verificar "$BASE/tangnano/verilog_tp4/project_tp4/top_tp4/src/top_tp4.cst" "066a0449fca93f1cb6a7785f4566caec"

echo ""
echo "=== Verificando raspberry/src/ ==="
verificar "$BASE/raspberry/src/bitwise_tp4.S"           "1baa11813804ea6720a5fa1ec00b3885"
verificar "$BASE/raspberry/src/conversao_tp4.S"          "82d6b631051c0eb82841af9dafc6372d"
verificar "$BASE/raspberry/src/gpio_teste_tp4.S"          "d672e0055e1ada246c993b5ba4c416ba"
verificar "$BASE/raspberry/src/lookup_tabela_tp4.S"        "f8d5218b9077c4fc8d4d62d75e74c4bc"
verificar "$BASE/raspberry/src/medicao_desempenho_tp4.S"    "4b3445cd8cfe2d9df816d1c1690d05de"
verificar "$BASE/raspberry/src/multipalavra_tp4.S"           "a579859345105a8c0e44c5b85be695aa"
verificar "$BASE/raspberry/src/neon_simd_tp4.S"               "4fc261ae33834d212660ebedc1d93784"
verificar "$BASE/raspberry/src/telemetria_gpio_tp4.S"          "05c33ae9bf76ab4bff296e2d92edcce9"

echo ""
echo "=== Verificando o Makefile ==="
verificar "$BASE/raspberry/Makefile" "278c090d0ebff2b0770cf5b2bf3439e8"

echo ""
if [ "$ERROS" -eq 0 ]; then
    echo "TUDO CONFERE. Os $((11+1+8+1)) arquivos estao na versao final e correta."
else
    echo "ATENCAO: $ERROS arquivo(s) precisam ser corrigidos antes de subir para o GitHub."
fi
