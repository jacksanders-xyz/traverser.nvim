-- traverser.nvim – a code-exploration dashboard
-- Ties together Trouble, Edgy, and a picker (Telescope or Snacks) into a
-- unified "traverser mode" with persistent traces through codebases.

local M = {}

---@class TraverserConfig
M.defaults = {
	-- Picker backend: "auto" | "telescope" | "snacks"
	-- "auto" will prefer snacks if available, then fall back to telescope
	picker = "auto",
	-- Drawer width for left/right Trouble panes
	drawer_size = 56,
	-- Bottom pane height
	bottom_size = 12,
	-- Edgy resize step (the "maximize" jump)
	resize_step_width = 76,
	resize_step_height = 10,
	-- Fine-grained resize (ctrl-arrow)
	resize_fine = 2,
	-- Disable animation in edgy
	animate = false,
	-- Modes to open on TraverserToggle (order matters for layout)
	dashboard_modes = {
		"traverser_symbols",
		"traverser_lsp",
		"traverser_incoming",
		"traverser_outgoing",
	},
	-- Auto-refresh events for call/reference panes
	refresh_events = { "CursorHold", "BufEnter" },
	-- Override keymaps – set false to disable defaults, or provide your own table
	keymaps = true,
}

---@type TraverserConfig
M.config = {}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

	-- Initialize submodules
	require("traverser.trouble").setup(M.config)
	require("traverser.edgy").setup(M.config)
	require("traverser.traces").setup(M.config)
	require("traverser.picker").setup(M.config)
	require("traverser.dashboard").setup(M.config)
	require("traverser.commands").setup(M.config)

	local backend = require("traverser.picker").backend()
	vim.notify("Traverser: using " .. backend .. " picker", vim.log.levels.INFO)
end

return M
