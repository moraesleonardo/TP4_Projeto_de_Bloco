`timescale 1ns/1ps
module unidade_aritmetica_tp4_tb;
    reg        clk, rst, entrada_valida;
    reg  [7:0] a, b, c;
    wire [7:0] media;
    wire       valida;
    integer    erros;

    unidade_aritmetica_tp4 #(.DATA_W(8)) dut (
        .clk(clk), .rst(rst), .entrada_valida(entrada_valida),
        .amostra_a(a), .amostra_b(b), .amostra_c(c),
        .media_suavizada(media), .saida_valida(valida)
    );

    always #5 clk = ~clk;

    // replica a mesma formula do RTL (coeficiente Q8 = 85) para autoverificacao
    function [7:0] esperado_f(input [7:0] va, input [7:0] vb, input [7:0] vc);
        reg [23:0] soma;
        reg [23:0] media_ext;
        begin
            soma = (va*8'd85) + (vb*8'd85) + (vc*8'd85);
            media_ext = soma >> 8;
            esperado_f = (media_ext > 24'd255) ? 8'd255 : media_ext[7:0];
        end
    endfunction

    task testar(input [7:0] va, input [7:0] vb, input [7:0] vc, input [127:0] rotulo);
        reg [7:0] esp;
        begin
            esp = esperado_f(va, vb, vc);
            // IMPORTANTE: so alteramos estimulos apos "@(posedge clk); #1;"
            // (nunca imediatamente apos a borda), para nao competir com a
            // propria avaliacao sincrona do DUT no mesmo delta de simulacao.
            @(posedge clk); #1;
            a = va; b = vb; c = vc; entrada_valida = 1'b1;
            @(posedge clk); #1;
            entrada_valida = 1'b0;
            @(posedge clk); #1; // latencia total = 2 ciclos (1 no MAC + 1 na soma)
            if (media !== esp || valida !== 1'b1) begin
                $display("FALHA [%0s] a=%0d b=%0d c=%0d esperado=%0d obtido=%0d valida=%b",
                          rotulo, va, vb, vc, esp, media, valida);
                erros = erros + 1;
            end else begin
                $display("OK    [%0s] a=%0d b=%0d c=%0d -> suavizada=%0d", rotulo, va, vb, vc, media);
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1; entrada_valida = 0; a=0; b=0; c=0; erros = 0;
        @(posedge clk); @(posedge clk);
        rst = 0;
        @(posedge clk);

        testar(8'd10, 8'd10, 8'd10, "AR-1 (constante)");
        testar(8'd0,  8'd255,8'd0,  "AR-2 (pico isolado)");
        testar(8'd255,8'd255,8'd255,"AR-3 (saturacao)");
        testar(8'd50, 8'd60, 8'd70, "AR-4 (rampa)");
        testar(8'd0,  8'd0,  8'd0,  "AR-5 (zero)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DA UNIDADE ARITMETICA PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NA UNIDADE ARITMETICA", erros);
        $finish;
    end
endmodule
