`timescale 1ns/1ps
module bram_frame_buffer_tp4_tb;
    reg        clk, we;
    reg  [5:0] end_escrita, end_leitura;
    reg  [7:0] dado_escrita;
    wire [7:0] dado_leitura;
    integer    erros, i;

    bram_frame_buffer_tp4 #(.DATA_W(8), .ADDR_W(6)) dut (
        .clk(clk), .we(we),
        .endereco_escrita(end_escrita), .dado_escrita(dado_escrita),
        .endereco_leitura(end_leitura), .dado_leitura(dado_leitura)
    );

    always #5 clk = ~clk;

    task escrever(input [5:0] end_e, input [7:0] valor);
        begin
            @(posedge clk); #1;
            end_escrita = end_e; dado_escrita = valor; we = 1'b1;
            @(posedge clk); #1;
            we = 1'b0;
        end
    endtask

    task ler_e_checar(input [5:0] end_l, input [7:0] esperado, input [127:0] rotulo);
        begin
            @(posedge clk); #1;
            end_leitura = end_l;
            @(posedge clk); #1; // leitura sincrona: 1 ciclo de latencia
            if (dado_leitura !== esperado) begin
                $display("FALHA [%0s] endereco=%0d esperado=%0d obtido=%0d", rotulo, end_l, esperado, dado_leitura);
                erros = erros + 1;
            end else begin
                $display("OK    [%0s] endereco=%0d -> %0d", rotulo, end_l, dado_leitura);
            end
        end
    endtask

    initial begin
        clk = 0; we = 0; end_escrita = 0; end_leitura = 0; dado_escrita = 0; erros = 0;

        // escreve uma sequencia conhecida nos enderecos 0..7
        escrever(6'd0, 8'd10);
        escrever(6'd1, 8'd45);
        escrever(6'd2, 8'd60);
        escrever(6'd3, 8'd200);
        escrever(6'd7, 8'd255);
        escrever(6'd63, 8'd1); // ultimo endereco valido (2^6-1)

        // le de volta e confirma
        ler_e_checar(6'd0,  8'd10,  "BRAM-1");
        ler_e_checar(6'd1,  8'd45,  "BRAM-2");
        ler_e_checar(6'd2,  8'd60,  "BRAM-3");
        ler_e_checar(6'd3,  8'd200, "BRAM-4");
        ler_e_checar(6'd7,  8'd255, "BRAM-5");
        ler_e_checar(6'd63, 8'd1,   "BRAM-6");
        ler_e_checar(6'd4,  8'd0,   "BRAM-7 (nao escrito, deve ser 0)");

        // sobrescreve um endereco ja usado e confirma atualizacao
        escrever(6'd0, 8'd77);
        ler_e_checar(6'd0, 8'd77, "BRAM-8 (sobrescrita)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DA BRAM PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NA BRAM", erros);
        $finish;
    end
endmodule
