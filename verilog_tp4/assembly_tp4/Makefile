# Makefile do TP4 - evolucao do Makefile do TP3 (mesma estrutura e
# convencoes), estendido para os novos programas Assembly do TP4.
#
# Uso normal, no Raspberry Pi Zero 2W (ferramentas nativas aarch64):
#   make all
#   make run PROG=multipalavra_tp4
#   make disasm PROG=neon_int_tp4
#   make clean
#
# Uso em ambiente de desenvolvimento x86 (fora do Raspberry Pi), para
# montagem cruzada e testes via qemu-aarch64, sobrescrevendo as ferramentas:
#   make all AS=aarch64-linux-gnu-as LD=aarch64-linux-gnu-ld OBJDUMP=aarch64-linux-gnu-objdump
#   make run PROG=multipalavra_tp4 RUN_PREFIX=qemu-aarch64

# Diretorios do projeto (padrao ja adotado em TP3/raspberry)
SRC_DIR := src
OBJ_DIR := obj
BIN_DIR := bin

# Ferramentas de compilacao (nomes padrao; sobrescritas via linha de
# comando quando a montagem cruzada for necessaria, ver cabecalho acima)
AS      := as
LD      := ld
OBJDUMP := objdump
GDB     := gdb

# Prefixo de execucao: vazio no Raspberry Pi (execucao nativa); definido
# como "qemu-aarch64" em ambiente de desenvolvimento para montagem cruzada
RUN_PREFIX :=

# Flags de montagem (-g inclui informacoes de depuracao)
ASFLAGS := -g

# Programas herdados do TP3 (Capitulo 4 e 5 do TP3), mantidos no Makefile
# do TP4 para continuidade e possivel reexecucao/comparacao
PROGRAMS_TP3 := loop_classificacao_tp3 parsing_comandos_tp3 gpio_acesso_tp3

# Novos programas do TP4
PROGRAMS_TP4 := multipalavra_tp4 conversao_tp4 lookup_table_tp4 bitwise_tp4 \
                neon_int_tp4 neon_float_tp4 comunicacao_fpga_tp4 \
                medicao_desempenho_tp4

# gpio_fisico_tp4, telemetria_fpga_tp4 e telemetria_serial_tp4 sao tratados
# separadamente (ver alvos dedicados abaixo), pois possuem duas variantes
# de montagem (MODO_TESTE=0 ou 1)
PROGRAMS := $(PROGRAMS_TP3) $(PROGRAMS_TP4)

# Regra padrao: monta qualquer .S em .o correspondente
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.S
	$(AS) $(ASFLAGS) -o $@ $<

# Regra padrao: vincula qualquer .o no executavel correspondente
$(BIN_DIR)/%: $(OBJ_DIR)/%.o
	$(LD) -o $@ $<

# Alvo principal: constroi todos os programas do TP3 e do TP4 de uma vez
.PHONY: all
all: $(patsubst %,$(BIN_DIR)/%,$(PROGRAMS)) gpio_fisico_tp4_teste gpio_fisico_tp4_real \
     telemetria_fpga_tp4_teste telemetria_fpga_tp4_real \
     telemetria_serial_tp4_teste telemetria_serial_tp4_real

# ----------------------------------------------------------------------
# gpio_fisico_tp4, telemetria_fpga_tp4 e telemetria_serial_tp4: duas
# variantes de montagem a partir do MESMO fonte, selecionadas pelo simbolo
# MODO_TESTE (ver comentario no topo de cada arquivo .S)
#
# NOTA: telemetria_fpga_tp4.S (barramento PARALELO, 11 pinos de dado) foi
# substituido por telemetria_serial_tp4.S (link SERIAL, 2 pinos) apos a
# decisao de reduzir o total de pinos dedicados ao ARM, liberando GPIOs
# para a camera OV7670. telemetria_fpga_tp4.S e mantido apenas como
# referencia/demonstracao isolada da logica de checksum/paridade - o
# programa que efetivamente conversa com o top_tp4.v atual (que expõe
# serial_data/serial_clk_ext, nao mais fpga_estado_pins/fpga_nivel_pins) e
# telemetria_serial_tp4.S.
# ----------------------------------------------------------------------
.PHONY: gpio_fisico_tp4_teste
gpio_fisico_tp4_teste: $(OBJ_DIR)/gpio_fisico_tp4_teste.o
	$(LD) -o $(BIN_DIR)/gpio_fisico_tp4_teste $(OBJ_DIR)/gpio_fisico_tp4_teste.o

$(OBJ_DIR)/gpio_fisico_tp4_teste.o: $(SRC_DIR)/gpio_fisico_tp4.S
	$(AS) $(ASFLAGS) --defsym MODO_TESTE=1 -o $@ $<

.PHONY: gpio_fisico_tp4_real
gpio_fisico_tp4_real: $(OBJ_DIR)/gpio_fisico_tp4_real.o
	$(LD) -o $(BIN_DIR)/gpio_fisico_tp4_real $(OBJ_DIR)/gpio_fisico_tp4_real.o

$(OBJ_DIR)/gpio_fisico_tp4_real.o: $(SRC_DIR)/gpio_fisico_tp4.S
	$(AS) $(ASFLAGS) -o $@ $<

.PHONY: telemetria_fpga_tp4_teste
telemetria_fpga_tp4_teste: $(OBJ_DIR)/telemetria_fpga_tp4_teste.o
	$(LD) -o $(BIN_DIR)/telemetria_fpga_tp4_teste $(OBJ_DIR)/telemetria_fpga_tp4_teste.o

$(OBJ_DIR)/telemetria_fpga_tp4_teste.o: $(SRC_DIR)/telemetria_fpga_tp4.S
	$(AS) $(ASFLAGS) --defsym MODO_TESTE=1 -o $@ $<

.PHONY: telemetria_fpga_tp4_real
telemetria_fpga_tp4_real: $(OBJ_DIR)/telemetria_fpga_tp4_real.o
	$(LD) -o $(BIN_DIR)/telemetria_fpga_tp4_real $(OBJ_DIR)/telemetria_fpga_tp4_real.o

$(OBJ_DIR)/telemetria_fpga_tp4_real.o: $(SRC_DIR)/telemetria_fpga_tp4.S
	$(AS) $(ASFLAGS) -o $@ $<

.PHONY: telemetria_serial_tp4_teste
telemetria_serial_tp4_teste: $(OBJ_DIR)/telemetria_serial_tp4_teste.o
	$(LD) -o $(BIN_DIR)/telemetria_serial_tp4_teste $(OBJ_DIR)/telemetria_serial_tp4_teste.o

$(OBJ_DIR)/telemetria_serial_tp4_teste.o: $(SRC_DIR)/telemetria_serial_tp4.S
	$(AS) $(ASFLAGS) --defsym MODO_TESTE=1 -o $@ $<

.PHONY: telemetria_serial_tp4_real
telemetria_serial_tp4_real: $(OBJ_DIR)/telemetria_serial_tp4_real.o
	$(LD) -o $(BIN_DIR)/telemetria_serial_tp4_real $(OBJ_DIR)/telemetria_serial_tp4_real.o

$(OBJ_DIR)/telemetria_serial_tp4_real.o: $(SRC_DIR)/telemetria_serial_tp4.S
	$(AS) $(ASFLAGS) -o $@ $<

# Uso: make disasm PROG=neon_int_tp4
.PHONY: disasm
disasm: $(BIN_DIR)/$(PROG)
	$(OBJDUMP) -d $(BIN_DIR)/$(PROG)

# Uso: make run PROG=multipalavra_tp4
# (no Raspberry Pi, RUN_PREFIX fica vazio e o binario roda nativamente;
# em ambiente de desenvolvimento, RUN_PREFIX=qemu-aarch64)
.PHONY: run
run: $(BIN_DIR)/$(PROG)
	$(RUN_PREFIX) ./$(BIN_DIR)/$(PROG); echo "codigo de saida: $$?"

# Uso: make gdb PROG=multipalavra_tp4
.PHONY: gdb
gdb: $(BIN_DIR)/$(PROG)
	$(GDB) $(BIN_DIR)/$(PROG)

# Roda a suite completa de testes do TP4 (ver rodar_testes.sh) e resume o resultado
.PHONY: testar
testar:
	./rodar_testes.sh

# Remove todos os arquivos objeto e executaveis gerados
.PHONY: clean
clean:
	rm -f $(OBJ_DIR)/*.o $(BIN_DIR)/*
	rm -f gpio_mem_simulado.bin
