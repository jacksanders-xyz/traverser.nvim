-- test/init.lua – minimal config for: nvim --clean -u test/init.lua
--
-- This bootstraps lazy.nvim, installs dependencies, and loads traverser.nvim
-- from the local checkout so you can iterate quickly.
--
-- Usage:
--   nvim --clean -u test/init.lua
--   (or use `make test` from the repo root)

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")

-- Use an isolated data/config directory so we don't pollute your real setup
local test_dir = root .. "/.test"
vim.env.XDG_CONFIG_HOME = test_dir .. "/config"
vim.env.XDG_DATA_HOME = test_dir .. "/data"
vim.env.XDG_STATE_HOME = test_dir .. "/state"
vim.env.XDG_CACHE_HOME = test_dir .. "/cache"

-- Bootstrap lazy.nvim
local lazypath = test_dir .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- Minimal settings
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.o.termguicolors = true
vim.o.updatetime = 300

------------------------------------------------------------------------
-- Pick your picker backend: "telescope", "snacks", or "auto"
-- Change this to test different backends.
------------------------------------------------------------------------
local USE_PICKER = "auto" -- "telescope" | "snacks" | "auto"

local picker_deps = {}
if USE_PICKER == "telescope" then
	picker_deps = {
		"nvim-telescope/telescope.nvim",
		"nvim-lua/plenary.nvim",
	}
elseif USE_PICKER == "snacks" then
	picker_deps = {
		{ "folke/snacks.nvim", opts = { picker = {} } },
	}
else -- "auto": install both, let traverser pick
	picker_deps = {
		{ "folke/snacks.nvim", opts = { picker = {} } },
		"nvim-telescope/telescope.nvim",
		"nvim-lua/plenary.nvim",
	}
end

require("lazy").setup({
	-- The plugin under development (local path)
	{
		dir = root,
		name = "traverser.nvim",
		dependencies = vim.list_extend({
			"folke/trouble.nvim",
			"folke/edgy.nvim",
		}, picker_deps),
		config = function()
			require("traverser").setup({
				picker = USE_PICKER,
				-- override other defaults here while testing
			})

			-- Your personal keymaps (the convention you keep in your dotfiles)
			local map = vim.keymap.set

			-- Dashboard
			map("n", "<leader>tm", "<Cmd>TraverserToggle<CR>", { desc = "Traverser: toggle dashboard" })

			-- Traces
			map("n", "<leader>ta", "<Cmd>TraverserAddNode<CR>", { desc = "Traverser: add/remove node" })
			map("n", "<leader>ty", "<Cmd>TraverserTree<CR>", { desc = "Traverser: open trace tree" })
			map("n", "<leader>tN", "<Cmd>TraverserNewTrace<CR>", { desc = "Traverser: new trace" })
			map("n", "<leader>tS", "<Cmd>TraverserSwitchTrace<CR>", { desc = "Traverser: switch trace" })
			map("n", "<leader>tE", "<Cmd>TraverserEdit<CR>", { desc = "Traverser: edit trace order" })
			map("n", "<leader>tc", function()
				require("traverser.traces").prompt_and_jump()
			end, { desc = "Traverser: jump to tag" })

			-- Focus panes
			map("n", "<leader>ts", "<Cmd>TraverserFocusSymbols<CR>", { desc = "Traverser: focus symbols" })
			map("n", "<leader>td", "<Cmd>TraverserFocusDiagnostics<CR>", { desc = "Traverser: focus diagnostics" })
			map("n", "<leader>tr", "<Cmd>TraverserFocusReferences<CR>", { desc = "Traverser: focus references" })
			map("n", "<leader>ti", "<Cmd>TraverserFocusIncoming<CR>", { desc = "Traverser: focus incoming" })
			map("n", "<leader>to", "<Cmd>TraverserFocusOutgoing<CR>", { desc = "Traverser: focus outgoing" })

			-- Maximize panes
			map("n", "<leader>t,s", "<Cmd>TraverserMaximizeSymbols<CR>", { desc = "Traverser: max symbols" })
			map("n", "<leader>t,d", "<Cmd>TraverserMaximizeDiagnostics<CR>", { desc = "Traverser: max diagnostics" })
			map("n", "<leader>t,r", "<Cmd>TraverserMaximizeReferences<CR>", { desc = "Traverser: max references" })
			map("n", "<leader>t,i", "<Cmd>TraverserMaximizeIncoming<CR>", { desc = "Traverser: max incoming" })
			map("n", "<leader>t,o", "<Cmd>TraverserMaximizeOutgoing<CR>", { desc = "Traverser: max outgoing" })

			-- Symbol pickers (works with either backend)
			map("n", "<C-p>", "<Cmd>TraverserSymbolsBuf<CR>", { desc = "Traverser: buffer symbols" })
			map("n", "<leader>O", "<Cmd>TraverserSymbolsWorkspace<CR>", { desc = "Traverser: workspace symbols" })

			-- Trouble navigation
			map("n", "<leader>J", "<Cmd>TraverserNext<CR>", { desc = "Traverser: next item" })
			map("n", "<leader>K", "<Cmd>TraverserPrev<CR>", { desc = "Traverser: prev item" })
		end,
	},

	-- A language server for testing (optional, uncomment what you need)
	-- { "neovim/nvim-lspconfig" },
	-- { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
})
