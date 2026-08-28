`timescale 1ns/1ps
// Testbench dedicado a gerar o arquivo .vcd para analise de waveform do
// comparador de frames. Percorre tres rodadas de comparacao evidenciando:
// (1) frames identicos (diferenca zero), (2) diferenca moderada (sem
// saturacao) e (3) diferenca maxima em todas as amostras (saturacao do
// nivel_movimento em 255, mesmo a soma real sendo bem maior).
module frame_diff_tp4_wave_tb;
    reg        clk, rst, iniciar;
    wire [2:0] endereco_leitura;
    reg  [7:0] dado_atual, dado_referencia;
    wire [15:0] soma_diferencas;
    wire [7:0]  nivel_movimento;
    wire        pronto;
    integer     i;

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

    always @(posedge clk) begin
        dado_atual      <= mem_atual[endereco_leitura];
        dado_referencia <= mem_ref[endereco_leitura];
    end

    task rodar(input [127:0] rotulo);
        begin
            @(posedge clk); #1;
            iniciar = 1'b1;
            @(posedge clk); #1;
            iniciar = 1'b0;
            wait (pronto == 1'b1);
            #1;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        $dumpfile("frame_diff_tp4.vcd");
        $dumpvars(0, frame_diff_tp4_wave_tb);

        clk = 0; rst = 1; iniciar = 0; dado_atual=0; dado_referencia=0;
        @(posedge clk); @(posedge clk); #1;
        rst = 0;

        // Rodada 1: frames identicos
        for (i = 0; i < 8; i = i + 1) begin
            mem_atual[i] = (i+1)*10;
            mem_ref[i]   = (i+1)*10;
        end
        rodar("identicos");

        // Rodada 2: diferenca moderada (soma=20, sem saturacao)
        mem_atual[0]=8'd10; mem_ref[0]=8'd15;
        mem_atual[1]=8'd20; mem_ref[1]=8'd20;
        mem_atual[2]=8'd30; mem_ref[2]=8'd25;
        mem_atual[3]=8'd40; mem_ref[3]=8'd40;
        mem_atual[4]=8'd50; mem_ref[4]=8'd55;
        mem_atual[5]=8'd60; mem_ref[5]=8'd60;
        mem_atual[6]=8'd70; mem_ref[6]=8'd65;
        mem_atual[7]=8'd80; mem_ref[7]=8'd80;
        rodar("diferenca_moderada");

        // Rodada 3: diferenca maxima -> soma real=2040, nivel_movimento SATURA em 255
        for (i = 0; i < 8; i = i + 1) begin
            mem_atual[i] = 8'd255;
            mem_ref[i]   = 8'd0;
        end
        rodar("saturacao");

        #20;
        $finish;
    end
endmodule
