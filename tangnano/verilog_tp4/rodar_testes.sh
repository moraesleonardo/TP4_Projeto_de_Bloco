#!/bin/bash
# Roda todos os testbenches Verilog do TP4 e resume o resultado.
set -u
cd "$(dirname "$0")"
SRC=src
TB=tb
OUT=/tmp/tp4_verilog_results.txt
> "$OUT"

run_test () {
    NOME=$1; shift
    echo "===== $NOME =====" | tee -a "$OUT"
    iverilog -o /tmp/sim_${NOME} "$@" 2>&1 | tee -a "$OUT"
    vvp /tmp/sim_${NOME} 2>&1 | tee -a "$OUT"
    echo "" >> "$OUT"
}

run_test heranca_tp2      $TB/heranca_tp2_tb.v $SRC/classificador_movimento_cfg.v $SRC/estado_para_leds.v
run_test dsp_mac          $TB/dsp_mac_tp4_tb.v $SRC/dsp_mac_tp4.v
run_test unidade_aritmetica $TB/unidade_aritmetica_tp4_tb.v $SRC/unidade_aritmetica_tp4.v $SRC/dsp_mac_tp4.v
run_test bram             $TB/bram_frame_buffer_tp4_tb.v $SRC/bram_frame_buffer_tp4.v
run_test sccb             $TB/sccb_master_tp4_tb.v $SRC/sccb_master_tp4.v
run_test camera           $TB/camera_ov7670_capture_tp4_tb.v $SRC/camera_ov7670_capture_tp4.v
run_test frame_diff       $TB/frame_diff_tp4_tb.v $SRC/frame_diff_tp4.v
run_test fsm              $TB/fsm_monitor_movimento_tp4_tb.v $SRC/fsm_monitor_movimento_tp4.v
run_test serial_out        $TB/serial_out_tp4_tb.v $SRC/serial_out_tp4.v
run_test top_integracao   $TB/top_tp4_tb.v $SRC/top_tp4.v $SRC/fsm_monitor_movimento_tp4.v $SRC/sccb_master_tp4.v $SRC/camera_ov7670_capture_tp4.v $SRC/bram_frame_buffer_tp4.v $SRC/frame_diff_tp4.v $SRC/classificador_movimento_cfg.v $SRC/estado_para_leds.v $SRC/serial_out_tp4.v

echo ""
echo "############################################"
echo "RESUMO FINAL"
echo "############################################"
grep -E "RESULTADO:|=====" "$OUT"
