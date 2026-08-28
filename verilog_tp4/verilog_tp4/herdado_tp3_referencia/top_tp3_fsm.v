module top_tp3_fsm (
    input  wire clk27,      // clock de 27 MHz embarcado na Tang Nano 20K
    input  wire btn_rst,    // botao fisico de reset
    input  wire btn_start,  // botao fisico de inicio/parada
    output wire led_normal,
    output wire led_atencao,
    output wire led_alerta
);

    fsm_monitor_movimento #(
        .HOLD_CYCLES(27_000_000)  // aproximadamente 1 segundo a 27 MHz
    ) fsm_inst (
        .clk(clk27),
        .rst(btn_rst),
        .start(btn_start),
        .led_normal(led_normal),
        .led_atencao(led_atencao),
        .led_alerta(led_alerta),
        .estado_atual(),      // saida de depuracao nao utilizada na sintese fisica
        .nivel_atual(),       // saida de depuracao nao utilizada na sintese fisica
        .estado_fsm_dbg()     // saida de depuracao nao utilizada na sintese fisica
    );

endmodule
