ROOT := $(shell pwd)

# Launch neovim with the test config (clean environment)
test:
	nvim --clean -u test/init.lua

# Same, but open a specific file for testing
test-file:
	nvim --clean -u test/init.lua $(FILE)

# Clean test artifacts
clean:
	rm -rf .test

.PHONY: test test-file clean
