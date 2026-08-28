`timescale 1ns/1ps
module serial_out_tp4_tb;
    reg         clk, rst, carregar, serial_clk_ext;
    reg  [9:0]  dado_paralelo;
    wire        serial_data;
    integer     erros, i;
    reg  [9:0]  reconstruido;

    serial_out_tp4 #(.LARGURA(10)) dut (
        .clk(clk), .rst(rst), .carregar(carregar), .dado_paralelo(dado_paralelo),
        .serial_clk_ext(serial_clk_ext), .serial_data(serial_data)
    );

    always #5 clk = ~clk;

    task pulsar_serial_clk;
        begin
            @(posedge clk); #1;
            serial_clk_ext = 1'b1;
            @(posedge clk); #1; // da tempo do sincronizador (2 FF) + deteccao de borda processarem
            @(posedge clk); #1;
            @(posedge clk); #1;
            serial_clk_ext = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    task testar_valor(input [9:0] valor, input [127:0] rotulo);
        begin
            @(posedge clk); #1;
            dado_paralelo = valor;
            carregar = 1'b1;
            @(posedge clk); #1;
            carregar = 1'b0;
            @(posedge clk); #1; // deixa o carregamento assentar

            // le o MSB sem nenhum pulso de clock ainda
            reconstruido = 0;
            reconstruido[9] = serial_data;

            for (i = 8; i >= 0; i = i - 1) begin
                pulsar_serial_clk;
                reconstruido[i] = serial_data;
            end

            if (reconstruido !== valor) begin
                $display("FALHA [%0s] esperado=%b (%0d) obtido=%b (%0d)",
                          rotulo, valor, valor, reconstruido, reconstruido);
                erros = erros + 1;
            end else begin
                $display("OK    [%0s] valor=%b (%0d) reconstruido corretamente via serial", rotulo, valor, valor);
            end
        end
    endtask

    initial begin
        clk=0; rst=1; carregar=0; serial_clk_ext=0; dado_paralelo=0; erros=0;
        @(posedge clk); @(posedge clk); #1;
        rst = 0;

        testar_valor(10'b10_11001000, "SER-1 (estado=2,nivel=200)");  // 0x2C8 = 712
        testar_valor(10'b00_00000000, "SER-2 (zero)");
        testar_valor(10'b11_11111111, "SER-3 (todos os bits em 1)");
        testar_valor(10'b01_01010101, "SER-4 (padrao alternado)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DO SERIAL_OUT PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NO SERIAL_OUT", erros);
        $finish;
    end
endmodule
