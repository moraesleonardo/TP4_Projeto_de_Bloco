// Restricao de clock para o pclk (vindo da saida PCLK da camera OV7670).
// Frequencia real depende do CLKRC interno da camera, nao configurado alem
// do reset; assume-se o pior caso (mesma frequencia do XCLK que alimenta a
// camera, 27 MHz) para garantir margem de timing segura mesmo que o clock
// real seja mais lento.
create_clock -name pclk -period 37 -waveform {0 18.5} [get_ports {pclk}]
