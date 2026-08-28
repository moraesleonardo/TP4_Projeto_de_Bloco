# Análise das waveforms do TP4

Este documento registra a análise das simulações funcionais dos três módulos mais
sensíveis do ponto de vista de comportamento numérico do TP4: a unidade aritmética
(suavização em ponto fixo), o comparador de frames (frame differencing) e a integração
completa do pipeline do MVP. As waveforms foram geradas com Icarus Verilog (arquivos
`.vcd`, incluídos nesta pasta) e renderizadas em figura com um script Python
(`plotar_vcd.py`, usando a biblioteca `vcdvcd`), no mesmo espírito da análise de
waveforms já feita no GTKWave nos relatórios do TP2 e do TP3.

## Figura W1 — `unidade_aritmetica_tp4` — suavização Q8 e quantização

Arquivo: `waveforms/figuras/fig_unidade_aritmetica.png` · fonte: `unidade_aritmetica_tp4.vcd`

A simulação aplicou 5 janelas de 3 amostras à unidade aritmética (coeficiente fixo
Q8 = 85/256 ≈ 0,332 aplicado a cada uma das 3 amostras). Os resultados observados na
waveform, com latência de 2 ciclos entre `entrada_valida` e `saida_valida`:

| Janela (a, b, c) | `media_suavizada` observada | Valor "ideal" (média aritmética exata) | Efeito de quantização |
|---|---|---|---|
| (10, 10, 10) | **9** | 10 | Arredondamento para baixo: o coeficiente 85/256 é levemente menor que 1/3, então mesmo em entrada constante o resultado quantizado fica 1 unidade abaixo do valor exato |
| (0, 255, 0) | **84** | 85 | Mesmo efeito de truncamento na divisão inteira (`>>8`) |
| (255, 255, 255) | **254** | 255 | **Saturação/quantização no teto**: mesmo com as 3 amostras no valor máximo (255), o resultado nunca alcança 255, pois `255×85×3 = 65025`, e `65025 >> 8 = 254` (o resto da divisão é descartado, não arredondado) |
| (50, 60, 70) | **59** | 60 | Confirma o mesmo padrão de arredondamento para baixo em uma rampa |
| (0, 0, 0) | **0** | 0 | Caso trivial, sem efeito de quantização a observar |

**Análise**: o padrão é consistente e sistemático — a unidade aritmética nunca
arredonda para cima, apenas para baixo (truncamento puro no deslocamento `>>8`, sem
bit de arredondamento). Isso é aceitável para o MVP (a classificação em
Normal/Atenção/Alerta usa faixas largas o suficiente para tolerar um desvio de 1
unidade), mas fica registrado como uma limitação de precisão do filtro de suavização
em ponto fixo: **o teto real do filtro é 254, nunca 255**, mesmo com entrada máxima
sustentada. Isso é coerente com o uso de um coeficiente fixo (85/256) em vez de uma
divisão exata por 3.

## Figura W2 — `frame_diff_tp4` — comparação entre frames e saturação

Arquivo: `waveforms/figuras/fig_frame_diff.png` · fonte: `frame_diff_tp4.vcd`

Três rodadas de comparação (8 amostras cada) foram simuladas:

1. **Frames idênticos** (`dado_atual` = `dado_referencia` em todas as 8 amostras):
   `soma_diferencas` permanece em 0 durante toda a rodada, e `nivel_movimento` conclui
   em **0**. Confirma que, sem alteração na cena, o sistema não gera falso positivo de
   movimento.
2. **Diferença moderada** (diferenças de 5 em 4 das 8 amostras, 0 nas outras 4):
   `soma_diferencas` cresce em degraus de 5 até **20**, e `nivel_movimento` = **20**
   (sem saturação, valor exato refletido).
3. **Diferença máxima** (`dado_atual`=255, `dado_referencia`=0 em todas as 8 amostras):
   `soma_diferencas` acumula em degraus de 255 (255, 510, 765, ..., **2040**), mas
   `nivel_movimento` **satura em 255** — o valor real da soma (2040) é quase 8 vezes
   maior que o máximo representável em 8 bits.

**Análise**: a waveform evidencia visualmente a diferença entre a grandeza interna de
16 bits (`soma_diferencas`, que soma corretamente até 2040) e a saída de 8 bits
saturada (`nivel_movimento`), confirmando que a saturação implementada não estoura
(*wraps around*) — ela satura corretamente no teto (255), preservando a ordenação
relativa da classificação (qualquer soma acima de 255 ainda é tratada como "o máximo
de alerta possível", nunca reaparecendo como um valor baixo por overflow).

## Figura W3 — `top_tp4` — pipeline completo do MVP (2 frames)

Arquivo: `waveforms/figuras/fig_top_tp4.png` · fonte: `top_tp4.vcd`

Mostra o ciclo de vida completo da FSM (`estado_fsm_dbg`: 0=Config, 1=Espera,
2=Captura, 3=Compara, 4=Exibe) ao longo de dois quadros capturados:

- No **1º quadro** (idêntico ao fundo, recém-capturado como referência):
  `fpga_nivel_pins` permanece em 0 e `fpga_estado_pins` em 0 (Normal); o LED físico
  `led_normal` está aceso (nível baixo, ativo-baixo).
- Na transição para o **2º quadro** (valores bem diferentes do fundo, simulando
  movimento forte), a FSM percorre novamente Captura → Compara → Exibe;
  `fpga_nivel_pins` salta para **255** (saturado) e `fpga_estado_pins` para **2**
  (Alerta) exatamente no início do novo estado Exibe. O LED físico `led_alerta` acende
  (cai para nível baixo) no mesmo instante, e `led_normal` apaga (sobe para nível
  alto).

**Análise**: a waveform confirma, em um único traço, a cadeia completa do MVP —
captura → comparação → classificação → indicação física — respondendo corretamente a
uma mudança de cena entre dois quadros consecutivos, com a telemetria
(`fpga_estado_pins`/`fpga_nivel_pins`) e os LEDs mudando de forma sincronizada e no
momento esperado (entrada no estado Exibe).

## Observação sobre os arquivos `.vcd`

Os três arquivos `.vcd` desta pasta podem ser abertos diretamente no GTKWave (mesma
ferramenta usada nos relatórios do TP2/TP3) para inspeção interativa adicional, caso
seja necessário aprofundar algum ponto específico no relatório final.
