-- traverser/picker/telescope.lua – Telescope backend
local M = {}

------------------------------------------------------------
-- Shared helper: refresh all traverser Trouble panes
------------------------------------------------------------
local function refresh_traverser_panes()
	local ok, trouble = pcall(require, "trouble")
	if ok and trouble.refresh then
		trouble.refresh({ mode = "symbols" })
		trouble.refresh({ mode = "traverser_symbols" })
		trouble.refresh({ "traverser_lsp" })
		trouble.refresh({ "traverser_references" })
		trouble.refresh({ "traverser_diagnostics" })
		trouble.refresh({ "traverser_incoming" })
		trouble.refresh({ "traverser_outgoing" })
	end
end

------------------------------------------------------------
-- Split opts: size the picker to fill the current editor window
------------------------------------------------------------
function M.split_opts()
	local win = vim.api.nvim_get_current_win()
	local ww = vim.api.nvim_win_get_width(win)
	local wh = vim.api.nvim_win_get_height(win)

	local ui_w, ui_h = vim.o.columns, vim.o.lines

	local gap_left, border_w = 0, 1
	local w_ratio = (ww - gap_left - border_w) / ui_w
	local h_ratio = wh / ui_h

	return {
		border = true,
		layout_strategy = "vertical",
		previewer = false,
		layout_config = {
			vertical = {
				width = w_ratio,
				height = h_ratio,
				prompt_position = "bottom",
				preview_cutoff = 0,
			},
		},
	}
end

------------------------------------------------------------
-- Peek action: jump in saved code window, refresh Trouble, stay in picker
------------------------------------------------------------
function M.make_peek(code_win_id)
	local api, fn = vim.api, vim.fn

	return function(_prompt_bufnr)
		local action_state = require("telescope.actions.state")
		local entry = action_state.get_selected_entry()
		if not entry then
			return
		end

		local loc = entry.value or entry
		local file = loc.filename or (loc.uri and vim.uri_to_fname(loc.uri))
		if not file then
			return
		end
		local line = (loc.lnum or (loc.range and loc.range.start.line) or 0)
		local col = loc.col or (loc.range and loc.range.start.character) or 0

		if not (code_win_id and api.nvim_win_is_valid(code_win_id)) then
			return
		end

		local bufnr = fn.bufadd(file)
		fn.bufload(bufnr)
		api.nvim_win_call(code_win_id, function()
			if api.nvim_win_get_buf(code_win_id) ~= bufnr then
				api.nvim_win_set_buf(code_win_id, bufnr)
			end
			api.nvim_win_set_cursor(code_win_id, { line, col })
		end)

		refresh_traverser_panes()
	end
end

------------------------------------------------------------
-- Symbol picker with peek support
------------------------------------------------------------
function M.symbols_picker(kind)
	local builtin = require("telescope.builtin")
	local code_win_id = vim.api.nvim_get_current_win()

	local picker_fn = (kind == "ws")
			and function(opts)
				builtin.lsp_dynamic_workspace_symbols(vim.tbl_extend("force", { default_text = "" }, opts))
			end
		or builtin.lsp_document_symbols

	picker_fn(vim.tbl_extend("force", M.split_opts(), {
		attach_mappings = function(_, map)
			map({ "i", "n" }, "<C-e>", M.make_peek(code_win_id))
			return true
		end,
	}))
end

------------------------------------------------------------
-- Trace switcher (telescope picker)
------------------------------------------------------------
function M.switch_trace_picker()
	local traces = require("traverser.traces")
	local store = traces.get_store()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	pickers
		.new({}, {
			prompt_title = "Traverser Traces",
			finder = finders.new_table(vim.tbl_map(function(t)
				return t.name
			end, store.traces)),
			attach_mappings = function(_, map)
				map({ "i", "n" }, "<C-d>", function(prompt_bufnr)
					local sel = action_state.get_selected_entry()
					traces.delete_trace(sel.index)
					actions.close(prompt_bufnr)
				end)

				map({ "i", "n" }, "<C-r>", function()
					local sel = action_state.get_selected_entry()
					vim.ui.input({ prompt = "Rename trace to: ", default = sel[1] }, function(new)
						if new and new ~= "" then
							traces.rename_trace(sel.index, new)
						end
					end)
				end)

				actions.select_default:replace(function(prompt_bufnr)
					local sel = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					traces.switch_trace(sel.index)
				end)

				return true
			end,
		})
		:find()
end

------------------------------------------------------------
-- Setup
------------------------------------------------------------
function M.setup(_config)
	-- Nothing to eagerly initialize; functions are called on demand
end

return M
