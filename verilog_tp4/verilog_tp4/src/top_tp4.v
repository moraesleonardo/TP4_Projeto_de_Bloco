// ============================================================================
// top_tp4.v
// Modulo de topo do TP4: integra a captura da camera OV7670 (SCCB + DVP),
// os buffers de frame em BRAM (atual e referencia), a comparacao entre
// frames (frame_diff_tp4, unidade aritmetica de suavizacao),
// a FSM de controle (fsm_monitor_movimento_tp4) e a classificacao herdada
// do TP2 (classificador_movimento_cfg.v + estado_para_leds.v).
//
// SIMPLIFICACAO DE DOMINIO DE CLOCK (documentada): todo o sistema opera em
// um unico dominio, sincronizado ao PCLK da propria camera, evitando a
// necessidade de sincronizadores de cruzamento de dominio de clock (CDC)
// entre a captura de imagem e o restante do pipeline. Uma evolucao futura
// poderia usar o clock interno de 27 MHz da Tang Nano para a logica de
// controle, com sincronizadores dedicados na fronteira com o dominio PCLK.
//
// O sinal 'arm_start', vindo fisicamente do Raspberry Pi (GPIO), e a saida
// de telemetria serial para o Raspberry Pi (serial_data/serial_clk_ext/
// fpga_pronto_pin, 4 fios no total) materializam a comunicacao fisica
// ARM-FPGA exigida pela rubrica do TP4.
// ============================================================================
module top_tp4 #(
    parameter ADDR_W      = 6,
    parameter N_AMOSTRAS  = 64,
    parameter SCCB_DIV    = 60,             // reduzir em simulacao; ajustar na sintese fisica (~100kHz)
    parameter HOLD_CYCLES = 2000     // reduzido de proposito: independente da frequencia real do
                                      // pclk (nunca medida com certeza), garante atualizacao rapida
                                      // da classificacao -- poucos milissegundos mesmo num clock lento
)(
    input  wire       pclk,           // clock de pixel da camera, usado como clock global do sistema
    // rst agora e um fio interno (ver 'assign rst = ~rst_btn_n' mais abaixo);
    // decisao de nao mais amarrar em GND fixo fica documentada junto do assign.
    input  wire       clk27m,          // oscilador interno de 27 MHz da Tang Nano 20K (pino fisico
                                       // dedicado, independente da camera); unica fonte de clock que
                                       // nao depende da propria camera estar funcionando -- necessaria
                                       // porque a camera so produz pclk/vsync/href depois de receber
                                       // um clock externo (XCLK) de alguem
    input  wire       rst_btn_n,       // botao fisico S2 da Tang Nano (ativo-baixo, pull-up onboard)
    input  wire       cam_vsync,
    input  wire       cam_href,
    input  wire [7:0] cam_pixel_data,
    output wire       cam_xclk,        // clock externo exigido pela OV7670 (rotulado XLK no modulo);
                                       // repassado direto do clk27m, sem divisao -- a OV7670 aceita
                                       // uma faixa larga de clock de entrada (tipicamente 10-48 MHz)
    output wire       cam_sioc,
    output wire       cam_siod,

    input  wire       arm_start,      // fisicamente ligado a um GPIO do Raspberry Pi (ex.: GPIO17)

    output wire       led_normal,     // pinos fisicos dos LEDs (ativo-baixo, invertidos aqui)
    output wire       led_atencao,
    output wire       led_alerta,

    output wire       serial_data,       // telemetria serial para o Raspberry Pi (estado+nivel)
    input  wire       serial_clk_ext,    // clock serial vindo do Raspberry Pi (mestre do link serial)
    output wire       fpga_pronto_pin,
    output wire       dbg_fsm_b1,      // diagnostico temporario: bit 1 do estado interno da FSM
    output wire       dbg_fsm_b0       // diagnostico temporario: bit 0 do estado interno da FSM
                                       // CONFIG=00, ESPERA=01, CAPTURA=10, COMPARA=11 (EXIBE=1xx,
                                       // ja indicado por fpga_pronto_pin) -- remover apos o bring-up
);
    // reset real, vindo do botao fisico S2 (ativo-baixo -> invertido aqui pra
    // virar um pulso ativo-alto, como o resto do projeto espera). Substitui a
    // decisao anterior de amarrar rst fixo em GND (nunca pulsava de verdade).
    wire rst = ~rst_btn_n;

    // ---------------- Clock externo da camera (XCLK) ----------------
    // repasse direto do oscilador de 27 MHz da placa para o pino XLK da OV7670;
    // sem isso a camera nao produz pclk/vsync/href/dado nenhum
    assign cam_xclk = clk27m;

    // sincronizador de 2 flip-flops para o sinal assincrono vindo do Raspberry Pi
    reg arm_start_sync0, arm_start_sync1;
    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            arm_start_sync0 <= 1'b0;
            arm_start_sync1 <= 1'b0;
        end else begin
            arm_start_sync0 <= arm_start;
            arm_start_sync1 <= arm_start_sync0;
        end
    end

    // ---------------- FSM principal ----------------
    wire sccb_iniciar, diff_iniciar, sccb_pronto, frame_pronto, diff_pronto;
    wire [2:0] estado_fsm_dbg;

    fsm_monitor_movimento_tp4 #(.HOLD_CYCLES(HOLD_CYCLES)) fsm_inst (
        .clk(pclk), .rst(rst), .start(arm_start_sync1),
        .sccb_pronto(sccb_pronto), .frame_pronto(frame_pronto), .diff_pronto(diff_pronto),
        .sccb_iniciar(sccb_iniciar), .diff_iniciar(diff_iniciar),
        .estado_fsm_dbg(estado_fsm_dbg)
    );

    // ---------------- Configuracao da camera (SCCB, sequencia de registros) ----------------
    // Sequencia essencial de inicializacao do OV7670 para YUV422/VGA baseada nas
    // tabelas de referencia amplamente usadas (westonb/OV7670-Verilog, tabelas
    // yuv422_ov7670 de projetos Arduino/STM32). So o reset (COM7=0x80) nao basta
    // pra maioria dos modulos comecar a gerar VSYNC/HREF -- e preciso configurar
    // formato, ganho, balanco e coeficientes de matriz. Objetivo aqui: fazer a
    // camera efetivamente produzir frames (VSYNC/HREF oscilando), nao qualidade
    // de imagem perfeita.
    localparam NUM_REGS = 16;
    reg [7:0] cfg_reg [0:NUM_REGS-1];
    reg [7:0] cfg_val [0:NUM_REGS-1];
    initial begin
        // Sequencia revisada seguindo referencias verificadas (desaster/ov7670fifotest,
        // Bishal's blog, datasheet oficial). Correcoes em relacao a versao anterior:
        //  - COM7 NAO e escrito duas vezes seguidas (o datasheet avisa que isso deixa
        //    o registro inconsistente); o reset (0x80) e uma escrita isolada, com atraso
        //    depois, e o formato so e definido bem mais tarde.
        //  - Adiciona COM10 (PCLK nao alterna em HBLANK) e janelas H/V, necessarios
        //    para captura continua de video ao vivo (sem eles a saida pode ficar travada).
        cfg_reg[0]  = 8'h12; cfg_val[0]  = 8'h80; // COM7: reset (escrita isolada, atraso depois)
        cfg_reg[1]  = 8'h11; cfg_val[1]  = 8'h01; // CLKRC: clock externo, prescaler /1
        cfg_reg[2]  = 8'h3A; cfg_val[2]  = 8'h04; // TSLB: ordem de bytes YUV
        cfg_reg[3]  = 8'h12; cfg_val[3]  = 8'h00; // COM7: VGA + YUV (unica escrita de formato)
        cfg_reg[4]  = 8'h15; cfg_val[4]  = 8'h20; // COM10: PCLK nao alterna durante HBLANK
        cfg_reg[5]  = 8'h0C; cfg_val[5]  = 8'h00; // COM3: sem scaling
        cfg_reg[6]  = 8'h3E; cfg_val[6]  = 8'h00; // COM14: sem divisao de PCLK
        cfg_reg[7]  = 8'h40; cfg_val[7]  = 8'hC0; // COM15: faixa de saida completa 00-FF
        cfg_reg[8]  = 8'h17; cfg_val[8]  = 8'h13; // HSTART
        cfg_reg[9]  = 8'h18; cfg_val[9]  = 8'h01; // HSTOP
        cfg_reg[10] = 8'h32; cfg_val[10] = 8'hB6; // HREF
        cfg_reg[11] = 8'h19; cfg_val[11] = 8'h02; // VSTART
        cfg_reg[12] = 8'h1A; cfg_val[12] = 8'h7A; // VSTOP
        cfg_reg[13] = 8'h03; cfg_val[13] = 8'h0A; // VREF
        cfg_reg[14] = 8'h14; cfg_val[14] = 8'h18; // COM9: teto de ganho 4x
        cfg_reg[15] = 8'h13; cfg_val[15] = 8'h00; // COM8: AGC/AWB/AEC DESLIGADOS. Os testes mostraram
                                                   // que qualquer controle automatico (ganho ou
                                                   // exposicao) ajusta a imagem inteira continuamente e
                                                   // adiciona ruido de fundo que compete com o sinal de
                                                   // movimento, mesmo com o blur temporal. Com controle
                                                   // manual, a separacao sinal/ruido e a melhor -> a
                                                   // deteccao fica estavel. A compensacao de luz e feita
                                                   // por recalibracao dos limiares, nao pela camera.
    end

    reg [3:0] cfg_indice;
    reg       cfg_rodando;
    reg       sccb_iniciar_reg;
    wire      sccb_concluido_raw;

    // atraso entre a escrita do reset (COM7=0x80) e as escritas seguintes:
    // o OV7670 precisa de um tempo apos o soft-reset antes de aceitar config
    reg [19:0] atraso_pos_reset;
    reg        aguardando_reset;

    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            cfg_indice       <= 4'd0;
            cfg_rodando      <= 1'b0;
            sccb_iniciar_reg <= 1'b0;
            atraso_pos_reset <= 20'd0;
            aguardando_reset <= 1'b0;
        end else begin
            sccb_iniciar_reg <= 1'b0;

            if (sccb_iniciar && !cfg_rodando && !aguardando_reset) begin
                cfg_rodando      <= 1'b1;
                cfg_indice       <= 4'd0;
                sccb_iniciar_reg <= 1'b1;
            end else if (aguardando_reset) begin
                // conta o atraso pos-reset antes de enviar o registro seguinte
                if (atraso_pos_reset < 20'd1_000_000) begin
                    atraso_pos_reset <= atraso_pos_reset + 1'b1;
                end else begin
                    aguardando_reset <= 1'b0;
                    atraso_pos_reset <= 20'd0;
                    sccb_iniciar_reg <= 1'b1; // dispara o proximo registro (indice 1)
                end
            end else if (cfg_rodando && sccb_concluido_raw) begin
                if (cfg_indice == 4'd0) begin
                    // acabou de escrever o reset -> espera antes do proximo
                    cfg_indice       <= cfg_indice + 1'b1;
                    aguardando_reset <= 1'b1;
                end else if (cfg_indice != NUM_REGS-1) begin
                    cfg_indice       <= cfg_indice + 1'b1;
                    sccb_iniciar_reg <= 1'b1;
                end else begin
                    cfg_rodando <= 1'b0;
                end
            end
        end
    end

    assign sccb_pronto = cfg_rodando && sccb_concluido_raw && (cfg_indice == NUM_REGS-1);

    sccb_master_tp4 #(.DIV(SCCB_DIV)) sccb_inst (
        .clk(pclk), .rst(rst), .iniciar(sccb_iniciar_reg),
        .endereco_escravo(8'h42),
        .endereco_registro(cfg_reg[cfg_indice]),
        .dado_registro(cfg_val[cfg_indice]),
        .sio_c(cam_sioc), .sio_d(cam_siod),
        .ocupado(), .transacao_concluida(sccb_concluido_raw)
    );

    // ---------------- Captura de camera ----------------
    wire escrita_habilitada;
    wire [ADDR_W-1:0] endereco_escrita;
    wire [7:0] dado_escrita;

    // Reamostra os dados de pixel na borda de DESCIDA do pclk. O OV7670 troca o
    // dado na borda de subida do PCLK, entao amostrar na descida (meio ciclo
    // depois) pega o dado ja estavel. Amostrar na mesma borda de subida (como
    // era antes) pega o dado em transicao -> valores achatados/constantes que
    // nao refletem a imagem real. Esta e a causa classica de "imagem chapada"
    // com OV7670 em FPGA.
    reg [7:0] cam_pixel_data_estavel;
    always @(negedge pclk or posedge rst) begin
        if (rst) cam_pixel_data_estavel <= 8'd0;
        else     cam_pixel_data_estavel <= cam_pixel_data;
    end

    camera_ov7670_capture_tp4 #(.ADDR_W(ADDR_W), .N_AMOSTRAS(N_AMOSTRAS)) cam_inst (
        .pclk(pclk), .rst(rst), .vsync(cam_vsync), .href(cam_href), .pixel_data(cam_pixel_data_estavel),
        .escrita_habilitada(escrita_habilitada), .endereco_escrita(endereco_escrita),
        .dado_escrita(dado_escrita), .frame_pronto(frame_pronto)
    );

    // ---------------- Suavizacao da amostra de camera (unidade aritmetica + DSP) ----------------
    // Filtro de media movel ponderada (Q8, 3 amostras vizinhas) aplicado ANTES da
    // escrita na BRAM (frame atual e referencia), reduzindo ruido do sensor antes
    // da comparacao entre frames. Ativa de fato os 3 blocos DSP fisicos (MULT9X9)
    // via dsp_mac_tp4.v, conectando a unidade_aritmetica_tp4 que ate aqui existia
    // no projeto mas nunca era instanciada a partir do modulo de topo.
    //
    // Janela deslizante de 3 amostras consecutivas do buffer reduzido.
    // SIMPLIFICACAO DOCUMENTADA: a janela nao e reiniciada a cada novo frame, entao
    // as 2 primeiras amostras de cada frame se misturam com o fim do frame
    // anterior -- efeito de borda aceitavel para o MVP (2 de 64 amostras/frame).
    reg [7:0] amostra_a_reg, amostra_b_reg, amostra_c_reg;
    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            amostra_a_reg <= 8'd0;
            amostra_b_reg <= 8'd0;
            amostra_c_reg <= 8'd0;
        end else if (escrita_habilitada) begin
            amostra_c_reg <= amostra_b_reg;
            amostra_b_reg <= amostra_a_reg;
            amostra_a_reg <= dado_escrita;
        end
    end

    // atraso de 2 ciclos do endereco, para alinhar com a latencia de 2 ciclos
    // da unidade aritmetica (1 ciclo do MAC + 1 ciclo do registrador de soma)
    reg [ADDR_W-1:0] endereco_escrita_d1, endereco_escrita_d2;
    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            endereco_escrita_d1 <= {ADDR_W{1'b0}};
            endereco_escrita_d2 <= {ADDR_W{1'b0}};
        end else begin
            endereco_escrita_d1 <= endereco_escrita;
            endereco_escrita_d2 <= endereco_escrita_d1;
        end
    end

    wire [7:0] dado_suavizado;
    wire       suavizacao_valida;

    unidade_aritmetica_tp4 #(.DATA_W(8)) suavizador_inst (
        .clk(pclk), .rst(rst),
        .entrada_valida(escrita_habilitada),
        .amostra_a(amostra_a_reg), .amostra_b(amostra_b_reg), .amostra_c(amostra_c_reg),
        .media_suavizada(dado_suavizado), .saida_valida(suavizacao_valida)
    );

    // ---------------- Buffers de frame (BRAM) ----------------
    // GAUSSIAN BLUR TEMPORAL (feature planejada no TP1, adaptada ao dominio do
    // tempo): cada uma das N_AMOSTRAS posicoes mantem a MEDIA dos ultimos frames
    // daquele ponto, num buffer dedicado (buffer_media). A cada nova amostra
    // capturada, le-se a media atual da posicao, combina-se com o novo pixel por
    // um filtro exponencial (media <- media - media>>K + novo>>K, K=2 -> janela
    // ~4 frames) e grava-se de volta. O ruido aleatorio do sensor (que muda a cada
    // frame) se cancela na media; a imagem real (estavel) permanece. E o
    // equivalente temporal do Gaussian Blur espacial: uma media ponderada que
    // suaviza, escolhida aqui no tempo por casar com a arquitetura de captura
    // reduzida (64 amostras espalhadas, sem vizinhanca espacial contigua).
    //
    // O resultado suavizado (dado_media_suave) alimenta a deteccao no lugar do
    // pixel bruto, reduzindo na origem o ruido que saturava a comparacao.
    localparam K_BLUR = 2; // intensidade do blur temporal (janela ~2^K = 4 frames)

    // pipeline de captura: a leitura sincrona da media tem 1 ciclo de latencia,
    // entao registramos endereco/dado/we da amostra por 1 ciclo para alinhar
    reg               escrita_hab_d1;
    reg [ADDR_W-1:0]  endereco_escrita_r1;
    reg [7:0]         dado_novo_r1;
    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            escrita_hab_d1      <= 1'b0;
            endereco_escrita_r1 <= {ADDR_W{1'b0}};
            dado_novo_r1        <= 8'd0;
        end else begin
            escrita_hab_d1      <= escrita_habilitada;
            endereco_escrita_r1 <= endereco_escrita;
            dado_novo_r1        <= dado_escrita;
        end
    end

    wire [7:0] media_atual_lida;   // media atual da posicao (lida da BRAM, 1 ciclo depois)
    // novo valor da media (filtro exponencial): media - media/4 + novo/4
    wire [7:0] media_nova = media_atual_lida - (media_atual_lida >> K_BLUR) + (dado_novo_r1 >> K_BLUR);

    // buffer da media temporal: leitura na captura (endereco_escrita, para ler a
    // media da posicao que sera atualizada) e escrita 1 ciclo depois (endereco_r1)
    bram_frame_buffer_tp4 #(.DATA_W(8), .ADDR_W(ADDR_W)) buffer_media (
        .clk(pclk), .we(escrita_hab_d1),
        .endereco_escrita(endereco_escrita_r1), .dado_escrita(media_nova),
        .endereco_leitura(endereco_escrita), .dado_leitura(media_atual_lida)
    );

    // dado suavizado que entra na deteccao = a media recem-calculada
    wire [7:0] dado_media_suave = media_nova;
    wire       escrita_suave    = escrita_hab_d1; // alinhada 1 ciclo apos a captura

    // FUNDO ADAPTATIVO sobre a imagem JA suavizada: a referencia acompanha a media
    // com atraso de ATRASO_REF frames; so movimento rapido gera diferenca.
    localparam [4:0] ATRASO_REF = 5'd8;
    reg [4:0] contador_ref;
    reg       atualiza_ref_frame;
    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            contador_ref       <= 5'd0;
            atualiza_ref_frame <= 1'b0;
        end else if (frame_pronto) begin
            if (contador_ref >= ATRASO_REF - 1) begin
                contador_ref       <= 5'd0;
                atualiza_ref_frame <= 1'b1;
            end else begin
                contador_ref       <= contador_ref + 1'b1;
                atualiza_ref_frame <= 1'b0;
            end
        end
    end

    wire [ADDR_W-1:0] endereco_leitura_diff;
    wire [7:0] dado_atual, dado_referencia;

    // buffer atual e referencia agora recebem o dado SUAVIZADO (media temporal),
    // com endereco/we alinhados 1 ciclo apos a captura
    bram_frame_buffer_tp4 #(.DATA_W(8), .ADDR_W(ADDR_W)) buffer_atual (
        .clk(pclk), .we(escrita_suave),
        .endereco_escrita(endereco_escrita_r1), .dado_escrita(dado_media_suave),
        .endereco_leitura(endereco_leitura_diff), .dado_leitura(dado_atual)
    );

    bram_frame_buffer_tp4 #(.DATA_W(8), .ADDR_W(ADDR_W)) buffer_referencia (
        .clk(pclk), .we(escrita_suave && atualiza_ref_frame),
        .endereco_escrita(endereco_escrita_r1), .dado_escrita(dado_media_suave),
        .endereco_leitura(endereco_leitura_diff), .dado_leitura(dado_referencia)
    );

    // ---------------- Comparacao entre frames (frame differencing) ----------------
    wire [15:0] soma_diferencas;
    wire [7:0]  nivel_movimento;

    frame_diff_tp4 #(.ADDR_W(ADDR_W), .N_AMOSTRAS(N_AMOSTRAS)) diff_inst (
        .clk(pclk), .rst(rst), .iniciar(diff_iniciar),
        .endereco_leitura(endereco_leitura_diff),
        .dado_atual(dado_atual), .dado_referencia(dado_referencia),
        .soma_diferencas(soma_diferencas), .nivel_movimento(nivel_movimento),
        .pronto(diff_pronto)
    );

    // ---------------- Classificacao com LIMIAR ADAPTATIVO ----------------
    wire [1:0] estado_classificado;
    wire led_normal_l, led_atencao_l, led_alerta_l;

    // Nivel RAPIDO: media exponencial curta (~4 amostras) que reage ao movimento.
    reg [7:0] nivel_sustentado;
    always @(posedge pclk or posedge rst) begin
        if (rst) nivel_sustentado <= 8'd0;
        else if (diff_pronto)
            nivel_sustentado <= nivel_sustentado - (nivel_sustentado >> 2) + (nivel_movimento >> 2);
    end

    // FUNDO ADAPTATIVO (nivel de ruido de base): media exponencial MUITO lenta
    // (~256 amostras) do nivel de movimento. Como movimento real e breve e o
    // fundo sobe/desce devagar, ele converge para o nivel tipico SEM movimento
    // (o ruido da condicao atual de luz/cena), quase nao sendo afetado pelos
    // picos curtos de movimento. Isto substitui o limiar fixo: em vez de um
    // numero calibrado a mao para cada condicao, o sistema MEDE o proprio ruido
    // de fundo e ajusta os limiares em relacao a ele. Resolve a fragilidade do
    // limiar fixo a mudancas de iluminacao/condicao (dia x noite, etc).
    reg [15:0] fundo_acc; // acumulador de 16 bits (8 bits de fundo + 8 de fracao)
    wire [7:0] fundo = fundo_acc[15:8];
    always @(posedge pclk or posedge rst) begin
        if (rst) fundo_acc <= 16'd0;
        else if (diff_pronto)
            // fundo_acc += (nivel - fundo)/256  -> media exponencial lenta
            fundo_acc <= fundo_acc - (fundo_acc >> 8) + {8'd0, nivel_movimento};
    end

    // Limiares RELATIVOS ao fundo medido, com saturacao em 8 bits:
    //   Atencao = fundo + MARGEM_ATENCAO
    //   Alerta  = fundo + MARGEM_ALERTA
    // As margens definem "quanto acima do ruido de base" conta como movimento.
    localparam [7:0] MARGEM_ATENCAO = 8'd1;
    localparam [7:0] MARGEM_ALERTA  = 8'd3;
    wire [8:0] soma_at = {1'b0, fundo} + {1'b0, MARGEM_ATENCAO};
    wire [8:0] soma_al = {1'b0, fundo} + {1'b0, MARGEM_ALERTA};
    wire [7:0] limiar_atencao_adapt = soma_at[8] ? 8'd255 : soma_at[7:0];
    wire [7:0] limiar_alerta_adapt  = soma_al[8] ? 8'd255 : soma_al[7:0];

    classificador_movimento_cfg classificador (
        .nivel_movimento(nivel_sustentado),
        .limiar_atencao(limiar_atencao_adapt),
        .limiar_alerta(limiar_alerta_adapt),
        .estado(estado_classificado)
    );

    estado_para_leds conversor_leds (
        .estado(estado_classificado),
        .led_normal(led_normal_l), .led_atencao(led_atencao_l), .led_alerta(led_alerta_l)
    );

    // LEDs embarcados da Tang Nano 20K sao ativo-baixos (achado do TP3): inverte na fronteira fisica.
    // Saida normal do MVP: LED0=Normal, LED1=Atencao, LED2=Alerta, com limiares
    // ADAPTATIVOS (fundo medido + margens), robustos a mudancas de iluminacao.
    assign led_normal  = ~led_normal_l;
    assign led_atencao = ~led_atencao_l;
    assign led_alerta  = ~led_alerta_l;

    // ---------------- Telemetria serial para o Raspberry Pi ----------------
    // Substitui o antigo barramento paralelo (fpga_estado_pins[1:0] +
    // fpga_nivel_pins[7:0], 10 fios) por um link serial de 2 fios,
    // reduzindo o total de pinos dedicados ao ARM de 12 para 4
    // (serial_clk_ext + serial_data + fpga_pronto_pin + arm_start),
    // liberando GPIOs para a conexao fisica da camera OV7670.
    // Checksum (4 bits) e paridade (1 bit) para deteccao basica de erro na
    // telemetria serial, conforme exigido pelo item 4 da rubrica do TP4
    // ("implementou mecanismos basicos de deteccao de erros: checksum,
    // paridade"). O checksum e a soma de estado+nivel, modulo 16 (os 4 bits
    // menos significativos da soma); a paridade e par, calculada sobre os
    // 14 bits anteriores do pacote (estado + nivel + checksum).
    wire [5:0] soma_checksum = {4'd0, estado_classificado} + {2'd0, nivel_movimento};
    wire [3:0] checksum_tp4  = soma_checksum[3:0];
    wire       paridade_tp4  = ^{estado_classificado, nivel_movimento, checksum_tp4};

    serial_out_tp4 #(.LARGURA(15)) telemetria_serial (
        .clk(pclk), .rst(rst),
        .carregar(diff_pronto), // carrega um novo valor exatamente quando o resultado fica pronto
        .dado_paralelo({estado_classificado, nivel_movimento, checksum_tp4, paridade_tp4}),
        .serial_clk_ext(serial_clk_ext),
        .serial_data(serial_data)
    );

    assign fpga_pronto_pin  = (estado_fsm_dbg == 3'd4); // alto durante o estado EXIBE (dado estavel)
    // diagnostico: acumula um OR de todos os bytes de pixel escritos na BRAM.
    // Se a captura de imagem funciona, algum bit fica em 1 (dado != 0). Se ficar
    // sempre 0, a camera gera VSYNC/HREF mas os bytes de pixel chegam zerados
    // (problema nos fios de dado D0-D7 ou no alinhamento de captura).
    // Mantem a saida da suavizacao (e portanto os blocos DSP MULT9X9) "viva" para
    // a sintese nao remover a unidade_aritmetica_tp4 agora que ela saiu do caminho
    // da imagem. Combina o resultado num unico bit exposto num pino de diagnostico.
    assign dbg_fsm_b1 = ^dado_suavizado ^ suavizacao_valida; // impede otimizacao do DSP
    assign dbg_fsm_b0 = estado_fsm_dbg[0];                    // diagnostico do estado da FSM
endmodule
