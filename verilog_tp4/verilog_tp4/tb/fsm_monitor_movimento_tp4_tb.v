`timescale 1ns/1ps
module fsm_monitor_movimento_tp4_tb;
    localparam CONFIG=3'd0, ESPERA=3'd1, CAPTURA=3'd2, COMPARA=3'd3, EXIBE=3'd4;

    reg clk, rst, start, sccb_pronto, frame_pronto, diff_pronto;
    wire sccb_iniciar, diff_iniciar;
    wire [2:0] estado_dbg;
    integer erros;

    fsm_monitor_movimento_tp4 #(.HOLD_CYCLES(3)) dut (
        .clk(clk), .rst(rst), .start(start),
        .sccb_pronto(sccb_pronto), .frame_pronto(frame_pronto), .diff_pronto(diff_pronto),
        .sccb_iniciar(sccb_iniciar), .diff_iniciar(diff_iniciar),
        .estado_fsm_dbg(estado_dbg)
    );

    always #5 clk = ~clk;

    task checar_estado(input [2:0] esperado, input [127:0] rotulo);
        begin
            if (estado_dbg !== esperado) begin
                $display("FALHA [%0s] estado esperado=%0d obtido=%0d", rotulo, esperado, estado_dbg);
                erros = erros + 1;
            end else begin
                $display("OK    [%0s] estado=%0d", rotulo, estado_dbg);
            end
        end
    endtask

    initial begin
        clk=0; rst=1; start=0; sccb_pronto=0; frame_pronto=0; diff_pronto=0; erros=0;
        @(posedge clk); @(posedge clk); #1;

        // apos reset (ainda em rst=1), estado deve ser CONFIG
        checar_estado(CONFIG, "F1-reset");
        if (sccb_iniciar !== 1'b1) begin
            $display("FALHA [F1-sccb_iniciar] esperado=1 obtido=%b", sccb_iniciar);
            erros = erros + 1;
        end else $display("OK    [F1-sccb_iniciar] pulso de disparo presente em CONFIG");

        rst = 0;
        @(posedge clk); #1; // sccb_disparado passa a 1 neste ciclo

        if (sccb_iniciar !== 1'b0) begin
            $display("FALHA [F2-sccb_iniciar] deveria ter caido para 0 apos o 1o ciclo, obtido=%b", sccb_iniciar);
            erros = erros + 1;
        end else $display("OK    [F2-sccb_iniciar] nao reenvia o disparo (apenas 1 pulso)");
        checar_estado(CONFIG, "F2-ainda-config");

        // conclui a configuracao SCCB -> deve ir para ESPERA
        @(posedge clk); #1;
        sccb_pronto = 1'b1;
        @(posedge clk); #1;
        sccb_pronto = 1'b0;
        checar_estado(ESPERA, "F3-pos-sccb-pronto");

        // sem start, permanece em ESPERA
        @(posedge clk); #1;
        checar_estado(ESPERA, "F4-sem-start");

        // ativa start -> vai para CAPTURA
        @(posedge clk); #1; start = 1'b1;
        @(posedge clk); #1;
        checar_estado(CAPTURA, "F5-apos-start");

        // aguardando frame_pronto, permanece em CAPTURA
        checar_estado(CAPTURA, "F6-aguardando-frame");

        // pulso de frame_pronto -> vai para COMPARA
        @(posedge clk); #1;
        frame_pronto = 1'b1;
        @(posedge clk); #1;
        frame_pronto = 1'b0;
        checar_estado(COMPARA, "F7-apos-frame-pronto");

        if (diff_iniciar !== 1'b1) begin
            $display("FALHA [F7-diff_iniciar] esperado=1 (nivel durante COMPARA) obtido=%b", diff_iniciar);
            erros = erros + 1;
        end else $display("OK    [F7-diff_iniciar] em nivel alto durante COMPARA");

        // pulso de diff_pronto -> vai para EXIBE
        @(posedge clk); #1;
        diff_pronto = 1'b1;
        @(posedge clk); #1;
        diff_pronto = 1'b0;
        checar_estado(EXIBE, "F8-apos-diff-pronto");

        // permanece em EXIBE por HOLD_CYCLES=3 ciclos, depois volta para CAPTURA (start=1)
        @(posedge clk); #1; checar_estado(EXIBE, "F9-exibe-1");
        @(posedge clk); #1; checar_estado(EXIBE, "F10-exibe-2");
        @(posedge clk); #1; checar_estado(EXIBE, "F11-exibe-3");
        @(posedge clk); #1; checar_estado(CAPTURA, "F12-volta-para-captura (start=1)");

        // repete o ciclo e desativa start durante EXIBE -> deve ir para ESPERA
        @(posedge clk); #1;
        frame_pronto = 1'b1;
        @(posedge clk); #1;
        frame_pronto = 1'b0;
        checar_estado(COMPARA, "F13-novo-ciclo-compara");
        @(posedge clk); #1;
        diff_pronto = 1'b1;
        @(posedge clk); #1;
        diff_pronto = 1'b0;
        checar_estado(EXIBE, "F14-novo-ciclo-exibe");
        @(posedge clk); #1; start = 1'b0; // desliga o start durante a exibicao
        @(posedge clk); #1; checar_estado(EXIBE, "F15-exibe-ainda");
        @(posedge clk); #1; checar_estado(EXIBE, "F16-exibe-ainda2");
        @(posedge clk); #1; checar_estado(ESPERA, "F17-volta-para-espera (start=0)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DA FSM TP4 PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NA FSM TP4", erros);
        $finish;
    end
endmodule
