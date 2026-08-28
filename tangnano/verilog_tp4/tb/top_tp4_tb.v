`timescale 1ns/1ps
module top_tp4_tb;
    localparam ADDR_W     = 6;
    localparam N_AMOSTRAS = 64;

    reg        pclk, rst, cam_vsync, cam_href, arm_start;
    reg  [7:0] cam_pixel_data;
    wire       cam_sioc, cam_siod;
    wire       led_normal, led_atencao, led_alerta;
    wire       serial_data, fpga_pronto_pin;
    reg        serial_clk_ext;
    integer    erros;

    reg [7:0] quadro [0:2*N_AMOSTRAS-1];
    reg [9:0] telemetria_lida;
    reg [1:0] estado_lido;
    reg [7:0] nivel_lido;

    top_tp4 #(
        .ADDR_W(ADDR_W), .N_AMOSTRAS(N_AMOSTRAS),
        .SCCB_DIV(2), .HOLD_CYCLES(10) // valores reduzidos para viabilizar a simulacao
    ) dut (
        .pclk(pclk), .rst(rst),
        .cam_vsync(cam_vsync), .cam_href(cam_href), .cam_pixel_data(cam_pixel_data),
        .cam_sioc(cam_sioc), .cam_siod(cam_siod),
        .arm_start(arm_start),
        .led_normal(led_normal), .led_atencao(led_atencao), .led_alerta(led_alerta),
        .serial_data(serial_data), .serial_clk_ext(serial_clk_ext), .fpga_pronto_pin(fpga_pronto_pin)
    );

    always #5 pclk = ~pclk;

    task montar_quadro_constante(input [7:0] valor_y);
        integer k;
        begin
            for (k = 0; k < N_AMOSTRAS; k = k + 1) begin
                quadro[2*k]   = valor_y;
                quadro[2*k+1] = 8'd99; // croma, descartada pelo capturador
            end
        end
    endtask

    task enviar_quadro;
        integer k;
        begin
            @(posedge pclk); #1;
            cam_vsync = 1'b0; // inicio do frame
            @(posedge pclk); #1;
            cam_href = 1'b1;
            cam_pixel_data = quadro[0];
            for (k = 1; k < 2*N_AMOSTRAS; k = k + 1) begin
                @(posedge pclk); #1;
                cam_pixel_data = quadro[k];
            end
            @(posedge pclk); #1;
            cam_href = 1'b0;
            @(posedge pclk); #1;
            cam_vsync = 1'b1; // fim do frame
            @(posedge pclk); #1; // deixa o frame_pronto assentar
        end
    endtask

    // Simula o Raspberry Pi lendo a telemetria serial: pulsa serial_clk_ext
    // e amostra serial_data, reconstruindo os 10 bits (estado + nivel).
    task ler_telemetria_serial;
        integer i;
        begin
            telemetria_lida = 0;
            telemetria_lida[9] = serial_data; // MSB ja disponivel, sem pulso de clock

            for (i = 8; i >= 0; i = i - 1) begin
                @(posedge pclk); #1;
                serial_clk_ext = 1'b1;
                @(posedge pclk); #1;
                @(posedge pclk); #1; // da tempo do sincronizador de 2 FF do lado da FPGA
                @(posedge pclk); #1;
                serial_clk_ext = 1'b0;
                @(posedge pclk); #1;
                telemetria_lida[i] = serial_data;
            end

            estado_lido = telemetria_lida[9:8];
            nivel_lido  = telemetria_lida[7:0];
        end
    endtask

    initial begin
        pclk = 0; rst = 1; cam_vsync = 1; cam_href = 0; cam_pixel_data = 0;
        arm_start = 0; serial_clk_ext = 0; erros = 0;
        @(posedge pclk); @(posedge pclk); #1;
        rst = 0;

        // aguarda a FSM concluir a configuracao SCCB (estado CONFIG -> ESPERA)
        repeat (300) @(posedge pclk);
        #1;
        if (dut.estado_fsm_dbg !== 3'd1) begin
            $display("FALHA [INT-1] FSM deveria estar em ESPERA (1) apos a config SCCB, obtido=%0d", dut.estado_fsm_dbg);
            erros = erros + 1;
        end else $display("OK    [INT-1] FSM em ESPERA apos configuracao SCCB concluida");

        // ativa o start fisico (simula GPIO do Raspberry Pi) e aguarda a sincronizacao (2 ciclos)
        @(posedge pclk); #1;
        arm_start = 1'b1;
        repeat (4) @(posedge pclk);
        #1;
        if (dut.estado_fsm_dbg !== 3'd2) begin
            $display("FALHA [INT-2] FSM deveria estar em CAPTURA (2), obtido=%0d", dut.estado_fsm_dbg);
            erros = erros + 1;
        end else $display("OK    [INT-2] FSM avancou para CAPTURA apos arm_start (comunicacao fisica ARM->FPGA)");

        // 1o frame: valor constante 10 (vira tambem o frame de referencia/fundo, 1a captura)
        montar_quadro_constante(8'd10);
        enviar_quadro;
        repeat (200) @(posedge pclk);
        #1;

        ler_telemetria_serial;
        if (nivel_lido !== 8'd0) begin
            $display("FALHA [INT-3] 1o frame == referencia recem-capturada, nivel_movimento deveria ser 0, obtido=%0d", nivel_lido);
            erros = erros + 1;
        end else $display("OK    [INT-3] nivel_movimento=0 no 1o frame (identico ao fundo capturado, lido via serial)");

        if (estado_lido !== 2'b00) begin
            $display("FALHA [INT-4] estado deveria ser Normal (00), obtido=%b", estado_lido);
            erros = erros + 1;
        end else $display("OK    [INT-4] estado classificado = Normal (telemetria serial FPGA->ARM)");

        if (led_normal !== 1'b0) begin // ativo-baixo: 0 = aceso
            $display("FALHA [INT-5] led_normal deveria estar aceso (0, ativo-baixo), obtido=%b", led_normal);
            erros = erros + 1;
        end else $display("OK    [INT-5] led_normal aceso (fisico ativo-baixo)");

        // aguarda a FSM sair do EXIBE e voltar para CAPTURA (start continua ativo)
        repeat (15) @(posedge pclk);
        #1;

        // 2o frame: valor bem diferente do fundo (simula movimento forte na cena)
        montar_quadro_constante(8'd250);
        enviar_quadro;
        repeat (200) @(posedge pclk);
        #1;

        // |250-10|=240 por amostra; soma = 64*240 = 15360 > 255 -> satura em 255
        ler_telemetria_serial;
        if (nivel_lido !== 8'd255) begin
            $display("FALHA [INT-6] 2o frame com diferenca forte, nivel_movimento esperado=255 (saturado), obtido=%0d", nivel_lido);
            erros = erros + 1;
        end else $display("OK    [INT-6] nivel_movimento=%0d apos o 2o frame (movimento detectado, lido via serial)", nivel_lido);

        if (estado_lido !== 2'b10) begin
            $display("FALHA [INT-7] estado deveria ser Alerta (10), obtido=%b", estado_lido);
            erros = erros + 1;
        end else $display("OK    [INT-7] estado classificado = Alerta (movimento significativo detectado)");

        if (led_alerta !== 1'b0) begin
            $display("FALHA [INT-8] led_alerta deveria estar aceso (0, ativo-baixo), obtido=%b", led_alerta);
            erros = erros + 1;
        end else $display("OK    [INT-8] led_alerta aceso (fisico ativo-baixo)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DE INTEGRACAO (TOP_TP4 / PIPELINE COMPLETO DO MVP, TELEMETRIA SERIAL) PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NA INTEGRACAO (TOP_TP4)", erros);
        $finish;
    end

    // watchdog de seguranca
    initial begin
        #2000000;
        $display("ERRO: timeout da simulacao de integracao (possivel travamento em algum submodulo)");
        $finish;
    end
endmodule
