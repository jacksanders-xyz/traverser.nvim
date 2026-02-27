-- traverser/picker/snacks.lua – Snacks.picker backend
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
-- Peek via on_change: jump in code window, refresh Trouble
------------------------------------------------------------
local function make_on_change(code_win_id)
	return function(_picker, item)
		if not item then
			return
		end

		local api, fn = vim.api, vim.fn
		local file = item.file or item.filename
		if not file then
			return
		end
		local line = item.pos and item.pos[1] or (item.lnum or 1)
		local col = item.pos and item.pos[2] or (item.col or 0)

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
	local code_win_id = vim.api.nvim_get_current_win()

	local opts = {
		layout = { preset = "vertical" },
		on_change = make_on_change(code_win_id),
		jump = { close = true },
	}

	if kind == "ws" then
		Snacks.picker.lsp_workspace_symbols(opts)
	else
		Snacks.picker.lsp_symbols(opts)
	end
end

------------------------------------------------------------
-- Trace switcher (snacks picker)
------------------------------------------------------------
function M.switch_trace_picker()
	local traces = require("traverser.traces")
	local store = traces.get_store()

	-- Build items list from traces
	local items = {}
	for i, trace in ipairs(store.traces) do
		table.insert(items, {
			idx = i,
			text = trace.name,
			trace_index = i,
		})
	end

	Snacks.picker({
		source = "traverser_traces",
		title = "Traverser Traces",
		items = items,
		format = "text",
		layout = { preset = "select" },
		confirm = function(picker, item)
			picker:close()
			if item then
				traces.switch_trace(item.trace_index)
			end
		end,
		actions = {
			delete_trace = function(picker)
				local item = picker:current()
				if item then
					traces.delete_trace(item.trace_index)
					picker:close()
					vim.schedule(function()
						M.switch_trace_picker()
					end)
				end
			end,
			rename_trace = function(picker)
				local item = picker:current()
				if not item then
					return
				end
				vim.ui.input({ prompt = "Rename trace to: ", default = item.text }, function(new)
					if new and new ~= "" then
						traces.rename_trace(item.trace_index, new)
						picker:close()
						vim.schedule(function()
							M.switch_trace_picker()
						end)
					end
				end)
			end,
		},
		win = {
			input = {
				keys = {
					["<C-d>"] = { "delete_trace", mode = { "i", "n" } },
					["<C-r>"] = { "rename_trace", mode = { "i", "n" } },
				},
			},
		},
	})
end

------------------------------------------------------------
-- Setup
------------------------------------------------------------
function M.setup(_config)
	-- Nothing to eagerly initialize; functions are called on demand
end

return M
