`timescale 1ns/1ps
module camera_ov7670_capture_tp4_tb;
    reg        pclk, rst, vsync, href;
    reg  [7:0] pixel_data;
    wire       escrita_habilitada, frame_pronto;
    wire [2:0] endereco_escrita;
    wire [7:0] dado_escrita;
    integer    erros, i;

    reg [7:0] buffer_observado [0:7];
    reg [7:0] esperado_y [0:7];

    camera_ov7670_capture_tp4 #(.ADDR_W(3), .N_AMOSTRAS(8)) dut (
        .pclk(pclk), .rst(rst), .vsync(vsync), .href(href), .pixel_data(pixel_data),
        .escrita_habilitada(escrita_habilitada), .endereco_escrita(endereco_escrita),
        .dado_escrita(dado_escrita), .frame_pronto(frame_pronto)
    );

    always #5 pclk = ~pclk;

    // "BRAM observadora": grava o que o capturador tenta escrever
    always @(posedge pclk) begin
        if (escrita_habilitada)
            buffer_observado[endereco_escrita] = dado_escrita;
    end

    reg [7:0] sequencia [0:15]; // 16 bytes por linha: Y0,U,Y1,U,...,Y7,U

    task enviar_byte(input [7:0] valor);
        begin
            @(posedge pclk); #1;
            pixel_data = valor;
        end
    endtask

    integer contador_frame_pronto;
    // IMPORTANTE: um segundo "always @(posedge pclk)" separado, lendo um sinal
    // que o proprio DUT atualiza via NBA na MESMA borda, pode enxergar o valor
    // antigo (mesma classe de corrida ja identificada nos testes anteriores).
    // A forma robusta de contar um pulso de 1 ciclo gerado por outro modulo
    // e reagir a mudanca do proprio sinal, nao a borda do clock.
    always @(posedge frame_pronto) contador_frame_pronto = contador_frame_pronto + 1;

    initial begin
        pclk = 0; rst = 1; vsync = 1; href = 0; pixel_data = 0; erros = 0;
        contador_frame_pronto = 0;
        for (i = 0; i < 8; i = i + 1) begin
            buffer_observado[i] = 8'hzz;
            esperado_y[i] = (i+1)*10; // 10,20,30,...,80
        end
        // monta a sequencia intercalada Y,U,Y,U,...,Y,U (16 bytes / linha)
        for (i = 0; i < 8; i = i + 1) begin
            sequencia[2*i]   = esperado_y[i]; // luma
            sequencia[2*i+1] = 8'd99;         // croma (descartada)
        end

        @(posedge pclk); @(posedge pclk); #1;
        rst = 0;

        // vsync em alto (blanking) por alguns ciclos, depois cai (inicio de frame)
        @(posedge pclk); #1;
        vsync = 1'b0; // borda de descida: inicio do frame reduzido

        // href sobe JUNTO com o primeiro byte valido (sequencia[0] = Y0),
        // para que a primeira borda em que href=1 ja carregue o dado correto
        @(posedge pclk); #1;
        href = 1'b1;
        pixel_data = sequencia[0];

        // envia os demais 15 bytes da linha (indices 1..15)
        for (i = 1; i < 16; i = i + 1)
            enviar_byte(sequencia[i]);

        @(posedge pclk); #1;
        href = 1'b0; // fim da linha ativa

        @(posedge pclk); #1;
        vsync = 1'b1; // borda de subida: fim do frame (deve gerar frame_pronto)

        @(posedge pclk); #1; // dá tempo do pulso ser contado

        // confere o buffer observado
        for (i = 0; i < 8; i = i + 1) begin
            if (buffer_observado[i] !== esperado_y[i]) begin
                $display("FALHA [CAM-BUF] endereco=%0d esperado=%0d obtido=%0d", i, esperado_y[i], buffer_observado[i]);
                erros = erros + 1;
            end else begin
                $display("OK    [CAM-BUF] endereco=%0d luma=%0d (croma descartada)", i, buffer_observado[i]);
            end
        end

        if (contador_frame_pronto !== 1) begin
            $display("FALHA [CAM-FRAME] frame_pronto pulsou %0d vez(es) (esperado 1)", contador_frame_pronto);
            erros = erros + 1;
        end else begin
            $display("OK    [CAM-FRAME] frame_pronto pulsou exatamente 1 vez ao concluir o frame reduzido");
        end

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DO CAPTURADOR DE CAMERA PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NO CAPTURADOR DE CAMERA", erros);
        $finish;
    end
endmodule
