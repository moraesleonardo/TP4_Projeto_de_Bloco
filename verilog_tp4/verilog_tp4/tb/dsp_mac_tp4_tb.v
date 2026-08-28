`timescale 1ns/1ps
module dsp_mac_tp4_tb;
    reg         clk, rst, valid_in;
    reg  [7:0]  dado, coef;
    reg  [23:0] acc_in;
    wire [23:0] acc_out;
    wire        valid_out;
    integer     erros;

    dsp_mac_tp4 #(.DATA_W(8), .COEF_W(8), .ACC_W(24)) dut (
        .clk(clk), .rst(rst), .valid_in(valid_in),
        .dado(dado), .coeficiente(coef), .acc_in(acc_in),
        .acc_out(acc_out), .valid_out(valid_out)
    );

    always #5 clk = ~clk;

    task aplicar_e_checar(input [7:0] d, input [7:0] c, input [23:0] ain, input [23:0] esperado, input [127:0] rotulo);
        begin
            dado = d; coef = c; acc_in = ain; valid_in = 1'b1;
            @(posedge clk); #1;
            if (acc_out !== esperado || valid_out !== 1'b1) begin
                $display("FALHA [%0s] dado=%0d coef=%0d acc_in=%0d -> esperado=%0d obtido=%0d valid=%b",
                          rotulo, d, c, ain, esperado, acc_out, valid_out);
                erros = erros + 1;
            end else begin
                $display("OK    [%0s] %0d*%0d+%0d = %0d", rotulo, d, c, ain, acc_out);
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1; valid_in = 0; dado=0; coef=0; acc_in=0; erros = 0;
        @(posedge clk); @(posedge clk);
        rst = 0;

        aplicar_e_checar(8'd10, 8'd85,  24'd0,   24'd850,  "MAC-1 (10*85+0)");
        aplicar_e_checar(8'd255,8'd85,  24'd850, 24'd22525,"MAC-2 (255*85+850)");
        aplicar_e_checar(8'd0,  8'd85,  24'd100, 24'd100,  "MAC-3 (0*85+100)");

        // verifica reset assincrono zera o acumulador e a saida
        rst = 1; #1;
        if (acc_out !== 24'd0 || valid_out !== 1'b0) begin
            $display("FALHA [RESET] acc_out=%0d valid_out=%b (esperado 0/0)", acc_out, valid_out);
            erros = erros + 1;
        end else begin
            $display("OK    [RESET] acumulador e valid_out zerados");
        end
        rst = 0;

        if (erros == 0)
            $display("RESULTADO: TODOS OS TESTES DO DSP MAC PASSARAM");
        else
            $display("RESULTADO: %0d FALHA(S) NO DSP MAC", erros);
        $finish;
    end
endmodule
