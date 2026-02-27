-- traverser/dashboard.lua – open/close/toggle the full traverser layout
local M = {}

local traverser_active = false
local traverser_grp = vim.api.nvim_create_augroup("TraverserMode", { clear = true })

------------------------------------------------------------
-- Refresh helper
------------------------------------------------------------
local function refresh_trouble_lists()
	if #vim.lsp.get_clients({ bufnr = 0 }) == 0 then
		return
	end
	local trouble = require("trouble")
	trouble.refresh({ mode = "lsp_incoming_calls" })
	trouble.refresh({ mode = "lsp_outgoing_calls" })
	trouble.refresh({ mode = "lsp_references" })
end

------------------------------------------------------------
-- Open the dashboard
------------------------------------------------------------
function M.open(config)
	config = config or require("traverser").config
	traverser_active = true

	local trouble = require("trouble")

	local modes = config.dashboard_modes or {
		"traverser_symbols",
		"traverser_lsp",
		"traverser_incoming",
		"traverser_outgoing",
	}

	for _, mode in ipairs(modes) do
		trouble.open({ mode = mode })
	end

	-- Keep panes fresh
	vim.api.nvim_create_autocmd(config.refresh_events or { "CursorHold", "BufEnter" }, {
		group = traverser_grp,
		callback = refresh_trouble_lists,
	})
end

------------------------------------------------------------
-- Close everything
------------------------------------------------------------
function M.close(config)
	config = config or require("traverser").config
	traverser_active = false
	vim.api.nvim_clear_autocmds({ group = traverser_grp })

	local trouble = require("trouble")
	local modes = config.dashboard_modes or {
		"traverser_symbols",
		"traverser_lsp",
		"traverser_incoming",
		"traverser_outgoing",
	}

	for _, mode in ipairs(modes) do
		trouble.close({ mode = mode })
	end

	pcall(vim.cmd, "lclose")
end

------------------------------------------------------------
-- Toggle
------------------------------------------------------------
function M.toggle(config)
	if traverser_active then
		M.close(config)
	else
		M.open(config)
	end
end

------------------------------------------------------------
-- Query state
------------------------------------------------------------
function M.is_active()
	return traverser_active
end

------------------------------------------------------------
-- Setup
------------------------------------------------------------
function M.setup(_config)
	-- State is managed internally; nothing to eagerly init
end

return M
