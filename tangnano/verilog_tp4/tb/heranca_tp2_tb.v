`timescale 1ns/1ps
// Testbench de confirmacao: valida que os modulos herdados do TP2
// (classificador_movimento_cfg.v e estado_para_leds.v) continuam se
// comportando exatamente como documentado nas Tabelas 7 e 8 do TP2,
// antes de serem reutilizados no TP4.
module heranca_tp2_tb;
    reg  [7:0] nivel, limiar_a, limiar_b;
    wire [1:0] estado;
    reg  [1:0] estado_forcado;
    wire       led_n, led_a, led_al;
    integer    erros;

    classificador_movimento_cfg cls (
        .nivel_movimento(nivel),
        .limiar_atencao(limiar_a),
        .limiar_alerta(limiar_b),
        .estado(estado)
    );

    estado_para_leds leds (
        .estado(estado_forcado),
        .led_normal(led_n),
        .led_atencao(led_a),
        .led_alerta(led_al)
    );

    task checar_estado(input [7:0] nv, input [1:0] esperado, input [127:0] rotulo);
        begin
            nivel = nv; #1;
            if (estado !== esperado) begin
                $display("FALHA [%0s] nivel=%0d esperado=%0d obtido=%0d", rotulo, nv, esperado, estado);
                erros = erros + 1;
            end else begin
                $display("OK    [%0s] nivel=%0d estado=%0d", rotulo, nv, estado);
            end
        end
    endtask

    task checar_led(input [1:0] est, input led_n_esp, input led_a_esp, input led_al_esp);
        begin
            estado_forcado = est; #1;
            if (led_n !== led_n_esp || led_a !== led_a_esp || led_al !== led_al_esp) begin
                $display("FALHA [LED] estado=%b esperado(n,a,al)=%b%b%b obtido=%b%b%b",
                          est, led_n_esp, led_a_esp, led_al_esp, led_n, led_a, led_al);
                erros = erros + 1;
            end else begin
                $display("OK    [LED] estado=%b -> led_normal=%b led_atencao=%b led_alerta=%b", est, led_n, led_a, led_al);
            end
        end
    endtask

    initial begin
        erros = 0;
        limiar_a = 8'd50;
        limiar_b = 8'd120;

        // Tabela 7 do TP2 (classificador_movimento_cfg)
        checar_estado(8'd10,  2'b00, "T7-1");
        checar_estado(8'd50,  2'b00, "T7-2");
        checar_estado(8'd51,  2'b01, "T7-3");
        checar_estado(8'd80,  2'b01, "T7-4");
        checar_estado(8'd120, 2'b01, "T7-5");
        checar_estado(8'd121, 2'b10, "T7-6");
        checar_estado(8'd180, 2'b10, "T7-7");
        checar_estado(8'd255, 2'b10, "T7-8");

        // Tabela 8 do TP2 (estado_para_leds)
        checar_led(2'b00, 1'b1, 1'b0, 1'b0);
        checar_led(2'b01, 1'b0, 1'b1, 1'b0);
        checar_led(2'b10, 1'b0, 1'b0, 1'b1);
        checar_led(2'b11, 1'b0, 1'b0, 1'b0);

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DE HERANCA TP2 PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NA HERANCA TP2", erros);
        $finish;
    end
endmodule
