-- traverser/edgy.lua – Edgy layout configuration + window focus/maximize helpers
local M = {}

------------------------------------------------------------
-- Window focus helper: find a Trouble split by mode
------------------------------------------------------------
local mode_lookup = {
	s = { "symbols", "traverser_symbols" },
	i = { "lsp_incoming_calls", "traverser_incoming" },
	o = { "lsp_outgoing_calls", "traverser_outgoing" },
	d = { "diagnostics", "traverser_diagnostics" },
	lr = { "lsp", "traverser_lsp" },
}

local function traverser_focus(modes)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local t = vim.w[win].trouble
		if t and t.type == "split" and t.relative == "editor" then
			for _, candidate in ipairs(modes) do
				if t.mode == candidate then
					vim.api.nvim_set_current_win(win)
					return win
				end
			end
		end
	end
	vim.notify("No matching Traverser window found", vim.log.levels.WARN)
	return nil
end

------------------------------------------------------------
-- Feedkey helper (respects mappings)
------------------------------------------------------------
local function feedkey_mapped(keystr)
	local term = vim.api.nvim_replace_termcodes(keystr, true, false, true)
	vim.api.nvim_feedkeys(term, "m", false)
end

------------------------------------------------------------
-- Maximize / restore state
------------------------------------------------------------
local current_maxed_win = nil

------------------------------------------------------------
-- Public API
------------------------------------------------------------

--- Focus a traverser pane by key (s, i, o, d, lr)
---@param mode_key string
function M.focus(mode_key)
	local modes = mode_lookup[mode_key]
	if not modes then
		vim.notify("Traverser: unknown pane key: " .. tostring(mode_key), vim.log.levels.ERROR)
		return
	end
	traverser_focus(modes)
end

--- Toggle-maximize a traverser pane by key
---@param mode_key string
function M.maximize(mode_key)
	local modes = mode_lookup[mode_key]
	if not modes then
		vim.notify("Traverser: unknown pane key: " .. tostring(mode_key), vim.log.levels.ERROR)
		return
	end

	local win = traverser_focus(modes)
	if not win then
		return
	end

	local t = vim.w[win].trouble
	local pos = t and t.position or "left"

	local grow_key, shrink_key
	if pos == "bottom" then
		grow_key = "<leader>TRU"
		shrink_key = "<leader>TRD"
	else
		grow_key = "<leader>TRR"
		shrink_key = "<leader>TRL"
	end

	-- Same window already maxed -> restore
	if current_maxed_win == win and vim.api.nvim_win_is_valid(win) then
		vim.schedule(function()
			feedkey_mapped(shrink_key)
			current_maxed_win = nil
		end)
		return
	end

	-- Different window was maxed -> restore it first
	if current_maxed_win and vim.api.nvim_win_is_valid(current_maxed_win) then
		vim.api.nvim_set_current_win(current_maxed_win)
		vim.schedule(function()
			local prev_t = vim.w[current_maxed_win].trouble
			local prev_pos = (prev_t and prev_t.position) or "left"
			if prev_pos == "bottom" then
				feedkey_mapped("<leader>TRD")
			else
				feedkey_mapped("<leader>TRL")
			end
		end)
	end

	-- Now maximize the requested one
	vim.api.nvim_set_current_win(win)
	vim.schedule(function()
		feedkey_mapped(grow_key)
		current_maxed_win = win
	end)
end

--- Get the mode_lookup table (for external use / extension)
function M.get_mode_lookup()
	return mode_lookup
end

------------------------------------------------------------
-- Setup: configure edgy.nvim
------------------------------------------------------------
function M.setup(config)
	local cfg = config or {}
	local resize_w = cfg.resize_step_width or 76
	local resize_h = cfg.resize_step_height or 10
	local resize_fine = cfg.resize_fine or 2

	local edgy_ok, edgy = pcall(require, "edgy")
	if not edgy_ok then
		-- edgy not installed yet; that's fine in a lazy-loading scenario
		return
	end

	local opts = {
		left = {
			size = { width = cfg.drawer_size or 53 },
		},
		bottom = {
			size = cfg.bottom_size or 12,
		},
		right = {},
		top = {},
		header = {
			show_in_active = true,
		},
		keys = {
			["<leader>TRR"] = function(win)
				win:resize("width", resize_w)
			end,
			["<leader>TRL"] = function(win)
				win:resize("width", -resize_w)
			end,
			["<leader>TRU"] = function(win)
				win:resize("height", resize_h)
			end,
			["<leader>TRD"] = function(win)
				win:resize("height", -resize_h)
			end,
			["<c-Right>"] = function(win)
				win:resize("width", resize_fine)
			end,
			["<c-Left>"] = function(win)
				win:resize("width", -resize_fine)
			end,
			["<c-Up>"] = function(win)
				win:resize("height", resize_fine)
			end,
			["<c-Down>"] = function(win)
				win:resize("height", -resize_fine)
			end,
		},
		animate = {
			enabled = cfg.animate or false,
		},
	}

	-- Register Trouble windows with Edgy for each position
	local traverser_modes = {
		"traverser_lsp",
		"traverser_symbols",
		"traverser_incoming",
		"traverser_outgoing",
		"traverser_diagnostics",
		"traverser_tree",
	}

	for _, pos in ipairs({ "top", "bottom", "left", "right" }) do
		opts[pos] = opts[pos] or {}

		-- Traverser windows
		table.insert(opts[pos], {
			ft = "trouble",
			title = "Traverser",
			size = (pos == "left" and { width = cfg.drawer_size or 50 } or nil),
			filter = function(_buf, win)
				local t = vim.w[win].trouble
				if not t or vim.w[win].trouble_preview then
					return false
				end

				local mode_ok = false
				for _, m in ipairs(traverser_modes) do
					if t.mode == m then
						mode_ok = true
						break
					end
				end

				return mode_ok and t.position == pos and t.type == "split" and t.relative == "editor"
			end,
		})

		-- Normal Trouble windows (non-traverser)
		table.insert(opts[pos], {
			ft = "trouble",
			title = "Trouble",
			size = (pos == "left" and { width = cfg.drawer_size or 50 } or nil),
			filter = function(_buf, win)
				local t = vim.w[win].trouble
				if not t or vim.w[win].trouble_preview then
					return false
				end

				local mode_ok = t.mode == "lsp"
					or t.mode == "symbols"
					or t.mode == "lsp_references"
					or t.mode == "lsp_incoming_calls"
					or t.mode == "lsp_outgoing_calls"
					or t.mode == "diagnostics"

				return mode_ok and t.position == pos and t.type == "split" and t.relative == "editor"
			end,
		})
	end

	edgy.setup(opts)
end

return M
