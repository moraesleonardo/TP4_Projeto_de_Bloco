`timescale 1ns/1ps
module top_tp4_wave_tb;
    localparam ADDR_W     = 6;
    localparam N_AMOSTRAS = 64;

    reg        pclk, rst, cam_vsync, cam_href, arm_start;
    reg  [7:0] cam_pixel_data;
    wire       cam_sioc, cam_siod;
    wire       led_normal, led_atencao, led_alerta;
    wire [1:0] fpga_estado_pins;
    wire [7:0] fpga_nivel_pins;
    wire       fpga_pronto_pin;
    integer    erros;

    reg [7:0] quadro [0:2*N_AMOSTRAS-1];

    top_tp4 #(
        .ADDR_W(ADDR_W), .N_AMOSTRAS(N_AMOSTRAS),
        .SCCB_DIV(2), .HOLD_CYCLES(10) // valores reduzidos para viabilizar a simulacao
    ) dut (
        .pclk(pclk), .rst(rst),
        .cam_vsync(cam_vsync), .cam_href(cam_href), .cam_pixel_data(cam_pixel_data),
        .cam_sioc(cam_sioc), .cam_siod(cam_siod),
        .arm_start(arm_start),
        .led_normal(led_normal), .led_atencao(led_atencao), .led_alerta(led_alerta),
        .fpga_estado_pins(fpga_estado_pins), .fpga_nivel_pins(fpga_nivel_pins), .fpga_pronto_pin(fpga_pronto_pin)
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

    initial begin
        $dumpfile("top_tp4.vcd");
        $dumpvars(0, top_tp4_wave_tb);

        pclk = 0; rst = 1; cam_vsync = 1; cam_href = 0; cam_pixel_data = 0; arm_start = 0; erros = 0;
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
        if (fpga_nivel_pins !== 8'd0) begin
            $display("FALHA [INT-3] 1o frame == referencia recem-capturada, nivel_movimento deveria ser 0, obtido=%0d", fpga_nivel_pins);
            erros = erros + 1;
        end else $display("OK    [INT-3] nivel_movimento=0 no 1o frame (identico ao fundo capturado)");

        if (fpga_estado_pins !== 2'b00) begin
            $display("FALHA [INT-4] estado deveria ser Normal (00), obtido=%b", fpga_estado_pins);
            erros = erros + 1;
        end else $display("OK    [INT-4] estado classificado = Normal (telemetria FPGA->ARM)");

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
        if (fpga_nivel_pins !== 8'd255) begin
            $display("FALHA [INT-6] 2o frame com diferenca forte, nivel_movimento esperado=255 (saturado), obtido=%0d", fpga_nivel_pins);
            erros = erros + 1;
        end else $display("OK    [INT-6] nivel_movimento=%0d apos o 2o frame (movimento detectado contra o fundo)", fpga_nivel_pins);

        if (fpga_estado_pins !== 2'b10) begin
            $display("FALHA [INT-7] estado deveria ser Alerta (10), obtido=%b", fpga_estado_pins);
            erros = erros + 1;
        end else $display("OK    [INT-7] estado classificado = Alerta (movimento significativo detectado)");

        if (led_alerta !== 1'b0) begin
            $display("FALHA [INT-8] led_alerta deveria estar aceso (0, ativo-baixo), obtido=%b", led_alerta);
            erros = erros + 1;
        end else $display("OK    [INT-8] led_alerta aceso (fisico ativo-baixo)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DE INTEGRACAO (TOP_TP4 / PIPELINE COMPLETO DO MVP) PASSARAM");
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
