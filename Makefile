# UART — OSS CAD Suite flow for Lattice iCE40
#
#   make venv     create .venv and install Python deps (cocotb, pytest)
#   make test     run cocotb testbenches (SIM=icarus|verilator, WAVES=1)
#   make lint     Verilator lint of all RTL
#   make synth    Yosys synthesis -> build/uart_top.json
#   make pnr      nextpnr place & route -> build/uart_top.asc
#   make bit      icepack -> build/uart_top.bin
#   make prog     flash the board with iceprog
#   make clean    remove build outputs

# ---- Target (defaults: iCEBreaker, iCE40UP5K-SG48, 12 MHz) ----------------
BOARD    ?= icebreaker
DEVICE   ?= up5k
PACKAGE  ?= sg48
CLK_MHZ  ?= 12
TOP      ?= uart_top

PCF      := constraints/$(BOARD).pcf
SRCS     := $(wildcard src/*.sv)
BUILD    := build

VENV     := .venv
PYTHON   := $(VENV)/bin/python
SIM      ?= icarus
WAVES    ?= 0

# FPGA tools: use OSS CAD Suite from OSS_CAD if it exists, else whatever is on PATH
OSS_CAD  ?= /opt/oss-cad-suite
OSS_BIN  := $(if $(wildcard $(OSS_CAD)/bin/yosys),$(OSS_CAD)/bin/)
YOSYS    := $(OSS_BIN)yosys
NEXTPNR  := $(OSS_BIN)nextpnr-ice40
ICEPACK  := $(OSS_BIN)icepack
ICEPROG  := $(OSS_BIN)iceprog

.PHONY: all venv test lint synth pnr bit prog clean

all: bit

# ---- Python environment ----------------------------------------------------
venv: $(VENV)/.installed

$(VENV)/.installed: requirements.txt
	python3 -m venv $(VENV)
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -r requirements.txt
	touch $@

# ---- Simulation ------------------------------------------------------------
test: venv
	SIM=$(SIM) WAVES=$(WAVES) $(PYTHON) -m pytest tb/ -v

# ---- Lint ------------------------------------------------------------------
lint:
	verilator --lint-only -Wall -Isrc --top-module $(TOP) $(SRCS)

# ---- FPGA flow -------------------------------------------------------------
synth: $(BUILD)/$(TOP).json
pnr:   $(BUILD)/$(TOP).asc
bit:   $(BUILD)/$(TOP).bin

$(BUILD)/$(TOP).json: $(SRCS) | $(BUILD)
	$(YOSYS) -q -l $(BUILD)/yosys.log \
		-p 'read_verilog -sv $(SRCS); synth_ice40 -top $(TOP) -json $@'

$(BUILD)/$(TOP).asc: $(BUILD)/$(TOP).json $(PCF)
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --freq $(CLK_MHZ) \
		--json $< --pcf $(PCF) --asc $@ -l $(BUILD)/nextpnr.log

$(BUILD)/$(TOP).bin: $(BUILD)/$(TOP).asc
	$(ICEPACK) $< $@

prog: $(BUILD)/$(TOP).bin
	$(ICEPROG) $<

$(BUILD):
	mkdir -p $@

clean:
	rm -rf $(BUILD) results.xml tb/__pycache__ .pytest_cache
