NVIM ?= nvim
DEPS_DIR := deps

.PHONY: deps test test-unit test-integration clean

deps:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(DEPS_DIR)/mini.nvim" ]; then \
		echo "Cloning mini.nvim..."; \
		git clone --filter=blob:none --depth 1 https://github.com/echasnovski/mini.nvim $(DEPS_DIR)/mini.nvim; \
	fi

test: deps
	$(NVIM) --headless -u NONE -l tests/init.lua

test-unit: deps
	$(NVIM) --headless -u NONE -l tests/run_subset.lua unit

test-integration: deps
	$(NVIM) --headless -u NONE -l tests/run_subset.lua integration

clean:
	rm -rf $(DEPS_DIR)
