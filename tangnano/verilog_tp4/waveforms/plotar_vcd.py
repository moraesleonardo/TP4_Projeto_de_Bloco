#!/usr/bin/env python3
"""
Le um arquivo VCD e gera:
  1) uma figura .png estilo waveform (semelhante ao GTKWave) para os sinais
     indicados;
  2) uma analise textual das transicoes de sinal, no mesmo espirito da
     descricao de waveforms ja usada nos relatorios do TP2/TP3.
"""
import sys
from vcdvcd import VCDVCD
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def carregar(vcd_path):
    vcd = VCDVCD(vcd_path)
    return vcd

def valor_int(v):
    if v in ("x", "z", "X", "Z"):
        return None
    try:
        return int(v, 2)
    except ValueError:
        return None

def obter_serie(vcd, nome_sinal):
    candidatos = []
    for k in vcd.references_to_ids:
        base = k.split('.')[-1].split('[')[0]
        if base == nome_sinal:
            candidatos.append(k)
    if not candidatos:
        return None
    # prefere o sinal dentro do escopo 'dut' (porta do modulo sob teste),
    # caindo para o primeiro encontrado caso nao haja tal escopo
    candidatos.sort(key=lambda k: (".dut." not in k, len(k)))
    ref = candidatos[0]
    sid = vcd.references_to_ids[ref]
    tv = vcd.data[sid].tv  # lista de (tempo, valor_str)
    return tv

def plotar(vcd_path, sinais, titulo, saida_png, largura_bits=None):
    vcd = carregar(vcd_path)
    fig, eixos = plt.subplots(len(sinais), 1, figsize=(12, 1.4*len(sinais)), sharex=True)
    if len(sinais) == 1:
        eixos = [eixos]

    tempo_final = 0
    for nome, _ in sinais:
        serie = obter_serie(vcd, nome)
        if serie:
            tempo_final = max(tempo_final, serie[-1][0])

    for ax, (nome, largura) in zip(eixos, sinais):
        serie = obter_serie(vcd, nome)
        if serie is None:
            ax.set_title(f"{nome} (nao encontrado)")
            continue
        tempos = [t for t, v in serie] + [tempo_final]
        if largura == 1:
            valores = [1 if v == '1' else 0 for _, v in serie] + [1 if serie[-1][1]=='1' else 0]
            ax.step(tempos, valores, where='post')
            ax.set_ylim(-0.3, 1.3)
            ax.set_yticks([0,1])
        else:
            valores_num = [valor_int(v) for _, v in serie]
            # plota como "escada" numerica com rotulos
            xs, ys = [], []
            for i, (t, v) in enumerate(serie):
                xs.append(t)
                ys.append(valores_num[i] if valores_num[i] is not None else -1)
            xs.append(tempo_final)
            ys.append(ys[-1] if ys else -1)
            ax.step(xs, ys, where='post', color='tab:orange')
            for i in range(len(serie)):
                if valores_num[i] is not None:
                    ax.annotate(str(valores_num[i]), (serie[i][0], valores_num[i]),
                                textcoords="offset points", xytext=(2,4), fontsize=7)
        ax.set_ylabel(nome, rotation=0, ha='right', va='center', fontsize=9)
        ax.grid(True, alpha=0.3)

    eixos[-1].set_xlabel("tempo (ps)")
    fig.suptitle(titulo)
    fig.tight_layout()
    fig.savefig(saida_png, dpi=130)
    print(f"Figura salva em {saida_png}")

if __name__ == "__main__":
    modo = sys.argv[1]
    if modo == "aritmetica":
        plotar("unidade_aritmetica_tp4.vcd",
               [("clk",1), ("entrada_valida",1), ("amostra_a",8), ("amostra_b",8),
                ("amostra_c",8), ("media_suavizada",8), ("saida_valida",1)],
               "unidade_aritmetica_tp4 - suavizacao Q8 (quantizacao)",
               "figuras/fig_unidade_aritmetica.png")
    elif modo == "framediff":
        plotar("frame_diff_tp4.vcd",
               [("clk",1), ("iniciar",1), ("dado_atual",8), ("dado_referencia",8),
                ("soma_diferencas",16), ("nivel_movimento",8), ("pronto",1)],
               "frame_diff_tp4 - comparacao entre frames (saturacao)",
               "figuras/fig_frame_diff.png")
    elif modo == "top":
        plotar("top_tp4.vcd",
               [("arm_start",1), ("estado_fsm_dbg",3), ("fpga_nivel_pins",8),
                ("fpga_estado_pins",2), ("led_normal",1), ("led_atencao",1), ("led_alerta",1)],
               "top_tp4 - pipeline completo do MVP (2 frames)",
               "figuras/fig_top_tp4.png")
