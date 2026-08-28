`timescale 1ns/1ps
module frame_diff_tp4_tb;
    reg        clk, rst, iniciar;
    wire [2:0] endereco_leitura;
    reg  [7:0] dado_atual, dado_referencia;
    wire [15:0] soma_diferencas;
    wire [7:0]  nivel_movimento;
    wire        pronto;
    integer     erros, i;

    reg [7:0] mem_atual [0:7];
    reg [7:0] mem_ref   [0:7];

    frame_diff_tp4 #(.ADDR_W(3), .N_AMOSTRAS(8)) dut (
        .clk(clk), .rst(rst), .iniciar(iniciar),
        .endereco_leitura(endereco_leitura),
        .dado_atual(dado_atual), .dado_referencia(dado_referencia),
        .soma_diferencas(soma_diferencas), .nivel_movimento(nivel_movimento),
        .pronto(pronto)
    );

    always #5 clk = ~clk;

    // simula a leitura sincrona (1 ciclo de latencia) de duas BRAMs externas
    always @(posedge clk) begin
        dado_atual      <= mem_atual[endereco_leitura];
        dado_referencia <= mem_ref[endereco_leitura];
    end

    task rodar_comparacao(input [15:0] soma_esperada, input [7:0] nivel_esperado, input [127:0] rotulo);
        begin
            @(posedge clk); #1;
            iniciar = 1'b1;
            @(posedge clk); #1;
            iniciar = 1'b0;
            wait (pronto == 1'b1);
            #1;
            if (soma_diferencas !== soma_esperada || nivel_movimento !== nivel_esperado) begin
                $display("FALHA [%0s] soma esperada=%0d obtida=%0d | nivel esperado=%0d obtido=%0d",
                          rotulo, soma_esperada, soma_diferencas, nivel_esperado, nivel_movimento);
                erros = erros + 1;
            end else begin
                $display("OK    [%0s] soma=%0d nivel_movimento=%0d", rotulo, soma_diferencas, nivel_movimento);
            end
            @(posedge clk); #1; // ciclo de folga antes da proxima comparacao
        end
    endtask

    initial begin
        clk = 0; rst = 1; iniciar = 0; dado_atual = 0; dado_referencia = 0; erros = 0;
        @(posedge clk); @(posedge clk); #1;
        rst = 0;

        // Caso 1: frames identicos -> soma = 0
        for (i = 0; i < 8; i = i + 1) begin
            mem_atual[i] = (i+1)*10;
            mem_ref[i]   = (i+1)*10;
        end
        rodar_comparacao(16'd0, 8'd0, "FD-1 (frames identicos)");

        // Caso 2: diferencas conhecidas -> soma = 20
        mem_atual[0]=8'd10; mem_ref[0]=8'd15; // |10-15|=5
        mem_atual[1]=8'd20; mem_ref[1]=8'd20; // 0
        mem_atual[2]=8'd30; mem_ref[2]=8'd25; // |30-25|=5
        mem_atual[3]=8'd40; mem_ref[3]=8'd40; // 0
        mem_atual[4]=8'd50; mem_ref[4]=8'd55; // |50-55|=5
        mem_atual[5]=8'd60; mem_ref[5]=8'd60; // 0
        mem_atual[6]=8'd70; mem_ref[6]=8'd65; // |70-65|=5
        mem_atual[7]=8'd80; mem_ref[7]=8'd80; // 0
        rodar_comparacao(16'd20, 8'd20, "FD-2 (diferencas moderadas, soma=20)");

        // Caso 3: diferenca maxima em todas as posicoes -> saturacao em 255
        for (i = 0; i < 8; i = i + 1) begin
            mem_atual[i] = 8'd255;
            mem_ref[i]   = 8'd0;
        end
        rodar_comparacao(16'd2040, 8'd255, "FD-3 (saturacao: soma real=2040, nivel saturado=255)");

        // Caso 4: nova comparacao apos as anteriores, confirma que o modulo
        // pode ser reiniciado (novo pulso 'iniciar') sem retrigger indevido
        for (i = 0; i < 8; i = i + 1) begin
            mem_atual[i] = 8'd5;
            mem_ref[i]   = 8'd0;
        end
        rodar_comparacao(16'd40, 8'd40, "FD-4 (nova rodada apos FD-3, soma=40)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DO FRAME_DIFF PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NO FRAME_DIFF", erros);
        $finish;
    end

    // watchdog de seguranca
    initial begin
        #100000;
        $display("ERRO: timeout da simulacao (possivel travamento da FSM de comparacao)");
        $finish;
    end
endmodule
