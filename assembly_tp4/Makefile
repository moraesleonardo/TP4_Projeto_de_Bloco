# Makefile - TP4 Rotinas Numericas Avancadas em Assembly ARM64
# Segue a mesma estrutura/convencao adotada no Makefile do TP3.

AS = as
LD = ld
SRC_DIR = src
OBJ_DIR = obj
BIN_DIR = bin

PROGRAMAS_TESTE = multipalavra_tp4 conversao_tp4 lookup_tabela_tp4 bitwise_tp4 neon_simd_tp4 medicao_desempenho_tp4
PROGRAMAS = $(PROGRAMAS_TESTE) gpio_teste_tp4 telemetria_gpio_tp4

ASFLAGS = -g
BINARIOS = $(addprefix $(BIN_DIR)/,$(PROGRAMAS))

.PHONY: all clean test

all: $(BINARIOS)

$(BIN_DIR)/%: $(OBJ_DIR)/%.o | $(BIN_DIR)
	$(LD) -o $@ $<

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.S | $(OBJ_DIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Executa os 5 programas que nao precisam de privilegio nenhum, e mostra o
# codigo de saida de cada um
test: all
	@for prog in $(PROGRAMAS_TESTE); do \
		echo "--- $$prog ---"; \
		./$(BIN_DIR)/$$prog; \
		echo "codigo de saida: $$?"; \
	done

# telemetria_gpio_tp4 e gpio_teste_tp4 acessam /dev/mem (memoria fisica real)
# e por isso precisam rodar com sudo; ficam de fora do 'make test' automatico
gpio_teste: all
	sudo ./$(BIN_DIR)/gpio_teste_tp4; \
	echo "codigo de saida: $$?"

telemetria: all
	sudo ./$(BIN_DIR)/telemetria_gpio_tp4; \
	echo "codigo de saida: $$?"

clean:
	rm -f $(OBJ_DIR)/*.o $(BIN_DIR)/*
