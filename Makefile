.PHONY: test lint format

PLENARY_PATH ?= $(HOME)/.local/share/nvim/site/pack/vendor/start/plenary.nvim
PLUGIN_PATH := $(shell pwd)

test:
	nvim --headless \
		--cmd "set rtp^=$(PLENARY_PATH)" \
		--cmd "set rtp^=$(PLUGIN_PATH)" \
		-c "lua require('plenary.test_harness').test_directory('tests/spec/', { minimal_init = false })" \
		-c "qa!"

lint:
	selene lua/ plugin/

format:
	stylua lua/ plugin/ tests/

format-check:
	stylua --check lua/ plugin/ tests/
