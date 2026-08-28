`timescale 1ns/1ps
module sccb_master_tp4_tb;
    reg        clk, rst, iniciar;
    reg  [7:0] end_escravo, end_reg, dado;
    wire       sio_c, sio_d, ocupado, transacao_concluida;
    integer    erros;

    reg [26:0] quadro_recebido;
    integer    bits_capturados;

    sccb_master_tp4 #(.DIV(3)) dut (
        .clk(clk), .rst(rst), .iniciar(iniciar),
        .endereco_escravo(end_escravo), .endereco_registro(end_reg), .dado_registro(dado),
        .sio_c(sio_c), .sio_d(sio_d), .ocupado(ocupado), .transacao_concluida(transacao_concluida)
    );

    always #5 clk = ~clk;

    // "analisador de barramento": captura sio_d a cada borda de subida de sio_c
    // que ocorre especificamente durante o estado BIT_HIGH (3'd3) - ou seja,
    // um bit de dado real, excluindo a borda de subida de sio_c que tambem
    // ocorre durante a condicao de stop (estado STOP_HIGH).
    always @(posedge sio_c) begin
        if (dut.estado == 3'd3) begin // BIT_HIGH
            quadro_recebido = {quadro_recebido[25:0], sio_d};
            bits_capturados = bits_capturados + 1;
        end
    end

    task executar_transacao(input [7:0] esc, input [7:0] reg_end, input [7:0] val, input [127:0] rotulo);
        reg [7:0] id_rx, reg_rx, dado_rx;
        begin
            quadro_recebido = 0;
            bits_capturados = 0;
            @(posedge clk); #1;
            end_escravo = esc; end_reg = reg_end; dado = val; iniciar = 1'b1;
            @(posedge clk); #1;
            iniciar = 1'b0;
            // aguarda a conclusao da transacao (pulso transacao_concluida)
            wait (transacao_concluida == 1'b1);
            @(posedge clk); #1;

            if (bits_capturados !== 27) begin
                $display("FALHA [%0s] quantidade de bits capturados = %0d (esperado 27)", rotulo, bits_capturados);
                erros = erros + 1;
            end else begin
                // quadro_recebido = {id[7:0], nc, reg[7:0], nc, dado[7:0], nc}
                id_rx   = quadro_recebido[26:19];
                reg_rx  = quadro_recebido[17:10];
                dado_rx = quadro_recebido[8:1];
                if (id_rx !== esc || reg_rx !== reg_end || dado_rx !== val) begin
                    $display("FALHA [%0s] esperado id=%02h reg=%02h dado=%02h | obtido id=%02h reg=%02h dado=%02h",
                              rotulo, esc, reg_end, val, id_rx, reg_rx, dado_rx);
                    erros = erros + 1;
                end else begin
                    $display("OK    [%0s] id=%02h reg=%02h dado=%02h transmitidos corretamente", rotulo, id_rx, reg_rx, dado_rx);
                end
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1; iniciar = 0; end_escravo=0; end_reg=0; dado=0; erros = 0;
        quadro_recebido = 0; bits_capturados = 0;
        @(posedge clk); @(posedge clk); #1;
        rst = 0;

        // COM7 (0x12) = 0x80 (reset de registros da OV7670), ID de escrita 0x42
        executar_transacao(8'h42, 8'h12, 8'h80, "SCCB-1 (reset COM7)");
        // COM7 (0x12) = 0x04 (formato YUV, exemplo)
        executar_transacao(8'h42, 8'h12, 8'h04, "SCCB-2 (formato YUV)");
        // COM17 (0x42) = 0xFF (valor de teste com todos os bits em 1)
        executar_transacao(8'h42, 8'h42, 8'hFF, "SCCB-3 (todos os bits em 1)");
        // valor 0x00 (todos os bits em 0)
        executar_transacao(8'h42, 8'h00, 8'h00, "SCCB-4 (todos os bits em 0)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DO MESTRE SCCB PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NO MESTRE SCCB", erros);
        $finish;
    end

    // watchdog de seguranca
    initial begin
        #100000;
        $display("ERRO: timeout da simulacao (possivel travamento da FSM SCCB)");
        $finish;
    end
endmodule
