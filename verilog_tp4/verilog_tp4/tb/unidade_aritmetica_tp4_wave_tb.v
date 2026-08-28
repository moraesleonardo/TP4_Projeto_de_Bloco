`timescale 1ns/1ps
// Testbench dedicado a gerar o arquivo .vcd para analise de waveform da
// unidade aritmetica (filtro de suavizacao em ponto fixo Q8). Percorre uma
// sequencia de amostras que evidencia o comportamento de quantizacao:
// valores que produzem arredondamento para baixo, saturacao no teto (255)
// e o caso degenerado (todas as amostras iguais, sem suavizacao real).
module unidade_aritmetica_tp4_wave_tb;
    reg        clk, rst, entrada_valida;
    reg  [7:0] a, b, c;
    wire [7:0] media;
    wire       valida;

    unidade_aritmetica_tp4 #(.DATA_W(8)) dut (
        .clk(clk), .rst(rst), .entrada_valida(entrada_valida),
        .amostra_a(a), .amostra_b(b), .amostra_c(c),
        .media_suavizada(media), .saida_valida(valida)
    );

    always #5 clk = ~clk;

    task aplicar(input [7:0] va, input [7:0] vb, input [7:0] vc);
        begin
            @(posedge clk); #1;
            a = va; b = vb; c = vc; entrada_valida = 1'b1;
            @(posedge clk); #1;
            entrada_valida = 1'b0;
            @(posedge clk); #1;
            @(posedge clk); #1; // deixa o resultado estabilizado visivel na waveform
        end
    endtask

    initial begin
        $dumpfile("unidade_aritmetica_tp4.vcd");
        $dumpvars(0, unidade_aritmetica_tp4_wave_tb);

        clk = 0; rst = 1; entrada_valida = 0; a=0; b=0; c=0;
        @(posedge clk); @(posedge clk); #1;
        rst = 0;

        aplicar(8'd10,  8'd10,  8'd10);   // caso degenerado: entrada constante
        aplicar(8'd0,   8'd255, 8'd0);    // pico isolado -> quantizacao evidente (nao da exatamente 85)
        aplicar(8'd255, 8'd255, 8'd255);  // saturacao no teto (254, nao 255, por causa do coeficiente Q8)
        aplicar(8'd50,  8'd60,  8'd70);   // rampa suave -> media proxima do valor central
        aplicar(8'd0,   8'd0,   8'd0);    // zero

        #20;
        $finish;
    end
endmodule
