// ============================================================================
// unidade_aritmetica_tp4.v
// Unidade aritmetica do TP4: filtro de suavizacao (media movel ponderada em
// ponto fixo Q8), que atua como a versao simplificada do Gaussian Blur
// previsto no MVP do TP1. Recebe 3 amostras vizinhas (janela deslizante) e
// devolve a media suavizada, usando 3 instancias do bloco DSP (dsp_mac_tp4)
// para realizar as multiplicacoes por coeficiente em paralelo.
//
// Coeficiente adotado: 85/256 (~= 0.332, em Q8), aplicado igualmente as
// 3 amostras da janela, aproximando uma media aritmetica simples com
// pequeno peso extra por arredondamento de ponto fixo.
// ============================================================================
module unidade_aritmetica_tp4 #(
    parameter DATA_W = 8
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              entrada_valida,
    input  wire [DATA_W-1:0] amostra_a,
    input  wire [DATA_W-1:0] amostra_b,
    input  wire [DATA_W-1:0] amostra_c,
    output wire [DATA_W-1:0] media_suavizada,
    output wire               saida_valida
);
    localparam [7:0] COEF_Q8 = 8'd85; // ~1/3 em ponto fixo Q8 (85/256 ~= 0.332)

    wire [23:0] parcial_a, parcial_b, parcial_c;
    wire        v_a, v_b, v_c;

    dsp_mac_tp4 #(.DATA_W(DATA_W), .COEF_W(8), .ACC_W(24)) mac_a (
        .clk(clk), .rst(rst), .valid_in(entrada_valida),
        .dado(amostra_a), .coeficiente(COEF_Q8), .acc_in(24'd0),
        .acc_out(parcial_a), .valid_out(v_a)
    );
    dsp_mac_tp4 #(.DATA_W(DATA_W), .COEF_W(8), .ACC_W(24)) mac_b (
        .clk(clk), .rst(rst), .valid_in(entrada_valida),
        .dado(amostra_b), .coeficiente(COEF_Q8), .acc_in(24'd0),
        .acc_out(parcial_b), .valid_out(v_b)
    );
    dsp_mac_tp4 #(.DATA_W(DATA_W), .COEF_W(8), .ACC_W(24)) mac_c (
        .clk(clk), .rst(rst), .valid_in(entrada_valida),
        .dado(amostra_c), .coeficiente(COEF_Q8), .acc_in(24'd0),
        .acc_out(parcial_c), .valid_out(v_c)
    );

    reg [23:0] soma_reg;
    reg        valid_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            soma_reg  <= 24'd0;
            valid_reg <= 1'b0;
        end else begin
            soma_reg  <= parcial_a + parcial_b + parcial_c;
            valid_reg <= v_a; // as 3 instancias tem a mesma latencia (1 ciclo)
        end
    end

    // descala Q8 (>>8) e satura em DATA_W bits
    wire [23:0] media_estendida = soma_reg >> 8;
    assign media_suavizada = (media_estendida > ((1<<DATA_W)-1)) ? {DATA_W{1'b1}} : media_estendida[DATA_W-1:0];
    assign saida_valida    = valid_reg;
endmodule
