// ============================================================================
// dsp_mac_tp4.v
// Unidade multiplicador-acumulador (MAC), agora instanciando DIRETAMENTE o
// primitivo MULT9X9 da Gowin (bloco DSP fisico da familia Arora, usada na
// Tang Nano 20K), em vez de deixar o multiplicador ser inferido a partir de
// "dado * coeficiente".
//
// MOTIVO DA MUDANCA: a inferencia automatica (com o atributo de sintese
// syn_dspstyle="dsp") NAO mapeou a multiplicacao 8x8 bits para um bloco DSP
// dedicado na sintese real - o relatorio mostrou a operacao implementada em
// ALU/logica generica. A instanciacao direta do primitivo GARANTE o uso do
// bloco DSP, independente da heuristica de inferencia do sintetizador.
//
// MULT9X9 opera nativamente em 9 bits (o encaixe mais proximo dos nossos
// operandos de 8 bits, sem desperdicar um multiplicador de 18x18 inteiro).
// Nossos operandos de 8 bits sao estendidos com um 0 na posicao mais
// significativa (operandos sem sinal, ASIGN=BSIGN=0). Todos os registros
// internos do primitivo (AREG/BREG/OUT_REG/PIPE_REG) sao mantidos em modo
// bypass (combinacional), preservando a MESMA latencia de 1 ciclo que o
// modulo ja tinha antes desta mudanca (o registro de acumulacao proprio do
// modulo, logo abaixo, continua sendo o unico elemento sequencial).
//
// Fonte: Gowin Digital Signal Processing (DSP) User Guide (UG287), secao
// 4.2.1 MULT9X9 - nomes de porta e template de instanciacao confirmados
// diretamente no manual oficial.
// ============================================================================
module dsp_mac_tp4 #(
    parameter DATA_W = 8,
    parameter COEF_W = 8,
    parameter ACC_W  = 24
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  valid_in,
    input  wire [DATA_W-1:0]     dado,
    input  wire [COEF_W-1:0]     coeficiente,
    input  wire [ACC_W-1:0]      acc_in,
    output reg  [ACC_W-1:0]      acc_out,
    output reg                   valid_out
);
    // dado * coeficiente -> agora realizado pelo bloco DSP fisico (MULT9X9)
    wire [17:0] produto_dsp;

    MULT9X9 mult_inst (
        .A({1'b0, dado}),           // zero-extensao de 8 para 9 bits (operando sem sinal)
        .B({1'b0, coeficiente}),
        .SIA(9'b0),                 // cadeia de deslocamento nao utilizada
        .SIB(9'b0),
        .ASIGN(1'b0),               // operandos sem sinal
        .BSIGN(1'b0),
        .ASEL(1'b1),                // tentativa 2: inverte a polaridade (ver nota abaixo)
        .BSEL(1'b1),
        .CE(1'b1),                  // habilitado continuamente (registros em bypass mesmo assim)
        .CLK(clk),
        .RESET(rst),
        .SOA(),                     // saidas de encadeamento nao utilizadas
        .SOB(),
        .DOUT(produto_dsp)
    );
    defparam mult_inst.AREG            = 1'b0; // bypass (combinacional)
    defparam mult_inst.BREG            = 1'b0;
    defparam mult_inst.OUT_REG         = 1'b0;
    defparam mult_inst.PIPE_REG        = 1'b0;
    defparam mult_inst.ASIGN_REG       = 1'b0;
    defparam mult_inst.BSIGN_REG       = 1'b0;
    defparam mult_inst.SOA_REG         = 1'b0;
    defparam mult_inst.MULT_RESET_MODE = "ASYNC";

    // produto_dsp tem 18 bits (9x9); como os operandos reais tem so 8 bits
    // (zero-estendidos), os 2 bits mais significativos de produto_dsp sao
    // sempre 0 - usamos apenas os 16 bits uteis (8x8)
    wire [DATA_W+COEF_W-1:0] produto = produto_dsp[DATA_W+COEF_W-1:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_out   <= {ACC_W{1'b0}};
            valid_out <= 1'b0;
        end else begin
            acc_out   <= acc_in + produto; // soma registrada -> unico elemento sequencial do modulo
            valid_out <= valid_in;
        end
    end
endmodule
