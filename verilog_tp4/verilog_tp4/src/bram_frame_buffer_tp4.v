// ============================================================================
// bram_frame_buffer_tp4.v
// Buffer de armazenamento generico, escrito no padrao que o Gowin Synthesis
// reconhece e mapeia para um bloco BSRAM dedicado (leitura sincrona,
// porta unica) em vez de sintetizar em registradores/LUTs.
// Usado no TP4 para armazenar: (a) o frame atual reduzido, capturado da
// camera OV7670, e (b) o frame de referencia (background), permitindo a
// comparacao entre frames (frame differencing) do MVP do TP1.
// ============================================================================
module bram_frame_buffer_tp4 #(
    parameter DATA_W = 8,
    parameter ADDR_W = 6      // 2^6 = 64 posicoes (frame reduzido/simplificado)
)(
    input  wire              clk,
    input  wire              we,
    input  wire [ADDR_W-1:0] endereco_escrita,
    input  wire [DATA_W-1:0] dado_escrita,
    input  wire [ADDR_W-1:0] endereco_leitura,
    output reg  [DATA_W-1:0] dado_leitura
);
    reg [DATA_W-1:0] memoria [0:(1<<ADDR_W)-1] /* synthesis syn_ramstyle = "block_ram" */;
    integer i;

    // Inicializacao explicita em zero: reproduz em simulacao o valor inicial
    // que sera carregado no BSRAM da Gowin via arquivo de inicializacao,
    // evitando leituras indeterminadas ('x) em enderecos ainda nao escritos.
    initial begin
        for (i = 0; i < (1<<ADDR_W); i = i + 1)
            memoria[i] = {DATA_W{1'b0}};
    end

    always @(posedge clk) begin
        if (we)
            memoria[endereco_escrita] <= dado_escrita;
        dado_leitura <= memoria[endereco_leitura]; // leitura sincrona (padrao BSRAM)
    end
endmodule
