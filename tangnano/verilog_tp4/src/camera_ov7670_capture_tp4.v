// ============================================================================
// camera_ov7670_capture_tp4.v
// Captura da interface DVP/paralela da camera OV7670: sincroniza com PCLK,
// usa VSYNC para delimitar o inicio/fim de frame e HREF para indicar dado de
// linha valido, escrevendo um buffer reduzido de amostras de luminancia (Y)
// no formato de saida BRAM (bram_frame_buffer_tp4.v).
//
// SIMPLIFICACOES DOCUMENTADAS (mitigacao de risco tecnico prevista no TP1):
//  - Resolucao reduzida: apenas N_AMOSTRAS bytes de luminancia sao mantidos
//    por frame (nao o frame completo), suficiente para o MVP de deteccao de
//    movimento por diferenca entre frames.
//  - Formato assumido: YUV422, no qual os bytes validos (HREF=1) alternam
//    Y, U, Y, V, Y, U ... por linha; apenas os bytes de luminancia (Y) sao
//    mantidos, descartando a crominancia (irrelevante para deteccao de
//    movimento em escala de cinza).
// ============================================================================
module camera_ov7670_capture_tp4 #(
    parameter ADDR_W     = 6,  // largura do endereco do buffer reduzido
    parameter N_AMOSTRAS = 64  // quantidade de amostras de luma por frame reduzido
)(
    input  wire       pclk,        // clock de pixel vindo da camera
    input  wire       rst,
    input  wire       vsync,       // ativo em nivel alto durante o blanking vertical
    input  wire       href,        // ativo em nivel alto enquanto a linha tem dado valido
    input  wire [7:0] pixel_data,  // byte de pixel (YUV422: Y,U,Y,V,... por linha)
    output reg                  escrita_habilitada,
    output reg  [ADDR_W-1:0]    endereco_escrita,
    output reg  [7:0]           dado_escrita,       // amostra de luma (Y) capturada
    output reg                  frame_pronto        // pulso de 1 ciclo ao concluir um frame reduzido
);
    reg              vsync_anterior;
    reg              byte_e_luma;       // alterna a cada byte valido: 1 = proximo byte e luma (Y)
    // contador_amostra: quantas amostras ja foram GRAVADAS no buffer reduzido (0..N_AMOSTRAS)
    reg [ADDR_W:0]   contador_amostra;
    // contador_luma: conta TODOS os bytes de luma da imagem, para subamostrar
    // espalhado pelo quadro inteiro (1 amostra gravada a cada SUBAMOSTRA lumas)
    // em vez de so os primeiros N_AMOSTRAS pixels de um cantinho da imagem.
    reg [15:0]       contador_luma;
    localparam [15:0] SUBAMOSTRA = 16'd4800; // 1 amostra a cada ~4800 lumas: 64 amostras
                                              // espalhadas por todo o quadro VGA (~307200 lumas),
                                              // e nao so pelas primeiras linhas do topo

    reg href_anterior;

    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            vsync_anterior     <= 1'b0;
            href_anterior      <= 1'b0;
            byte_e_luma        <= 1'b1; // primeiro byte da linha e Y
            contador_amostra   <= {(ADDR_W+1){1'b0}};
            contador_luma      <= 16'd0;
            escrita_habilitada <= 1'b0;
            frame_pronto       <= 1'b0;
            endereco_escrita   <= {ADDR_W{1'b0}};
            dado_escrita       <= 8'd0;
        end else begin
            escrita_habilitada <= 1'b0;
            frame_pronto       <= 1'b0;

            // borda de descida do vsync: inicio de um novo frame -> zera os indices
            if (vsync_anterior && !vsync) begin
                contador_amostra <= {(ADDR_W+1){1'b0}};
                contador_luma    <= 16'd0;
                byte_e_luma      <= 1'b1;
            end

            // RE-ANCORAGEM POR LINHA: na borda de SUBIDA do href (inicio de cada
            // linha valida), reinicia o alinhamento Y/U/V. Assim, um byte perdido
            // numa linha nao "escorrega" o alinhamento de todas as linhas
            // seguintes -- cada linha comeca limpa, com o primeiro byte = Y. Isso
            // elimina o deslocamento das amostras entre frames (causa da oscilacao
            // selvagem do nivel mesmo com a cena parada).
            if (href && !href_anterior)
                byte_e_luma <= 1'b1;

            if (href) begin
                if (byte_e_luma) begin
                    // este e um byte de luminancia (Y). Grava no buffer so 1 a cada
                    // SUBAMOSTRA lumas, espalhando as N_AMOSTRAS amostras pelo quadro.
                    if (contador_luma == 16'd0 && contador_amostra < N_AMOSTRAS) begin
                        escrita_habilitada <= 1'b1;
                        endereco_escrita   <= contador_amostra[ADDR_W-1:0];
                        dado_escrita       <= pixel_data;
                        contador_amostra   <= contador_amostra + 1'b1;
                    end
                    if (contador_luma == SUBAMOSTRA-1)
                        contador_luma <= 16'd0;
                    else
                        contador_luma <= contador_luma + 1'b1;
                end
                byte_e_luma <= ~byte_e_luma; // alterna Y/U ou Y/V a cada byte
            end

            // borda de subida do vsync (fim do periodo de linhas ativas): fecha o frame.
            // dispara desde que ao menos 1 amostra tenha sido capturada.
            if (!vsync_anterior && vsync && contador_amostra != 0)
                frame_pronto <= 1'b1;

            vsync_anterior <= vsync;
            href_anterior  <= href;
        end
    end
endmodule
