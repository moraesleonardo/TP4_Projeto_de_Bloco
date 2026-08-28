// ============================================================================
// serial_out_tp4.v
// Substitui o barramento paralelo de telemetria (fpga_estado_pins[1:0] +
// fpga_nivel_pins[7:0], 10 fios) por um link serial de 2 fios: um clock
// (serial_clk_ext) fornecido PELO RASPBERRY PI, e uma linha de dado
// (serial_data) fornecida pela FPGA. Isso reduz o barramento ARM-FPGA de
// 12 fios (10 de dado + pronto + arm_start) para 4 fios (serial_clk +
// serial_data + pronto + arm_start), liberando pinos de GPIO para a
// conexao fisica da camera OV7670.
//
// Protocolo (o ARM e o mestre do clock, papel semelhante a um SPI so-MISO):
//  1) A FPGA carrega o registrador de deslocamento com {estado, nivel}
//     no mesmo ciclo em que 'carregar' e pulsado (ligado a diff_pronto no
//     top_tp4.v, ou seja, exatamente quando um novo resultado fica pronto).
//  2) serial_data ja apresenta o bit mais significativo (MSB) imediatamente
//     apos o carregamento, sem exigir uma borda de clock.
//  3) A cada borda de subida detectada em serial_clk_ext, o registrador
//     desloca 1 bit a esquerda, apresentando o proximo bit em serial_data.
//  4) O ARM le o bit atual, pulsa o clock, le o proximo bit, repetindo ate
//     ler todos os LARGURA bits (LARGURA-1 pulsos de clock no total).
//
// serial_clk_ext vem de outro chip (assincrono ao dominio pclk desta FPGA),
// por isso passa por um sincronizador de 2 flip-flops antes da deteccao de
// borda, seguindo a mesma pratica ja usada para arm_start em top_tp4.v.
// ============================================================================
module serial_out_tp4 #(
    parameter LARGURA = 10  // 2 bits de estado + 8 bits de nivel_movimento
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               carregar,        // pulso: carrega um novo valor no registrador
    input  wire [LARGURA-1:0] dado_paralelo,   // valor a transmitir (amostrado no pulso 'carregar')
    input  wire               serial_clk_ext,  // clock serial vindo do Raspberry Pi (assincrono)
    output wire               serial_data      // bit atual, MSB primeiro
);
    // sincronizador de 2 flip-flops + deteccao de borda de subida
    reg sclk_sync0, sclk_sync1, sclk_sync2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sclk_sync0 <= 1'b0; sclk_sync1 <= 1'b0; sclk_sync2 <= 1'b0;
        end else begin
            sclk_sync0 <= serial_clk_ext;
            sclk_sync1 <= sclk_sync0;
            sclk_sync2 <= sclk_sync1;
        end
    end
    wire sclk_borda_subida = sclk_sync1 & ~sclk_sync2;

    reg [LARGURA-1:0] registrador;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            registrador <= {LARGURA{1'b0}};
        end else if (carregar) begin
            registrador <= dado_paralelo;           // recarrega (tem prioridade sobre um deslocamento)
        end else if (sclk_borda_subida) begin
            registrador <= {registrador[LARGURA-2:0], 1'b0}; // desloca a esquerda
        end
    end

    assign serial_data = registrador[LARGURA-1]; // MSB sempre visivel, sem exigir borda de clock
endmodule
