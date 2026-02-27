# WIP

a mishmash of folke config


From the repo root:

```sh
make test
```

That runs `nvim --clean -u test/init.lua`. First launch will clone lazy.nvim and all dependencies into `.test/` (takes a minute), then you're in a clean neovim with traverser loaded.

To open it against an actual file:

```sh
make test-file FILE=/path/to/some/file.go
```

To force a specific picker backend, edit the line at the top of `test/init.lua`:

```lua
local USE_PICKER = "snacks"    -- or "telescope" or "auto"
```

To clean up the test environment and start fresh:

```sh
make clean
```

Note: for the dashboard (`<leader>tm`) to actually populate the Trouble panes, you'll need an LSP running. Uncomment these two lines in `test/init.lua` and add your server config:

```lua
{ "neovim/nvim-lspconfig" },
{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
```

Without an LSP, traces (`<leader>tN`, `<leader>ta`, `<leader>tS`) and the edgy layout will still work -- the LSP panes will just say "no results".
