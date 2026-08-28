set orig_dir [pwd]

create_project -name top_tp4 -dir ./project_tp4 -pn GW2AR-LV18QN88C8/I7 -device_version C -force

add_file $orig_dir/src/top_tp4.v
add_file $orig_dir/src/fsm_monitor_movimento_tp4.v
add_file $orig_dir/src/sccb_master_tp4.v
add_file $orig_dir/src/camera_ov7670_capture_tp4.v
add_file $orig_dir/src/dsp_mac_tp4.v
add_file $orig_dir/src/unidade_aritmetica_tp4.v
add_file $orig_dir/src/bram_frame_buffer_tp4.v
add_file $orig_dir/src/frame_diff_tp4.v
add_file $orig_dir/src/serial_out_tp4.v
add_file $orig_dir/src/classificador_movimento_cfg.v
add_file $orig_dir/src/estado_para_leds.v

set_option -top_module top_tp4

run syn

puts "===================================================================="
puts "SINTESE CONCLUIDA - tentando Place and Route agora (sem .cst ainda,"
puts "so para ver como a ferramenta reage a pinos nao restringidos)"
puts "===================================================================="

run pnr
