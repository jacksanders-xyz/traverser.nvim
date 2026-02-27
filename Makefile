ROOT := $(shell pwd)

# Launch neovim with the test config (clean environment)
test:
	nvim --clean -u test/init.lua

# Open a specific file, with cwd set to that file's directory
# so LSP servers (gopls, etc.) can find project roots.
# Usage: make test-file FILE=/path/to/main.go
test-file:
	cd $(dir $(FILE)) && nvim --clean -u $(ROOT)/test/init.lua $(FILE)

# Clean test artifacts
clean:
	rm -rf .test

.PHONY: test test-file clean
