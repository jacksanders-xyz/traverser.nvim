-- traverser/commands.lua – User commands and default keymaps
local M = {}

function M.setup(config)
	local traces = require("traverser.traces")
	local dashboard = require("traverser.dashboard")
	local edgy = require("traverser.edgy")
	local picker = require("traverser.picker")

	----------------------------------------------------------------------
	-- User commands
	----------------------------------------------------------------------

	vim.api.nvim_create_user_command("TraverserToggle", function()
		dashboard.toggle(config)
	end, { desc = "Toggle the Traverser dashboard" })

	vim.api.nvim_create_user_command("TraverserOpen", function()
		dashboard.open(config)
	end, { desc = "Open the Traverser dashboard" })

	vim.api.nvim_create_user_command("TraverserClose", function()
		dashboard.close(config)
	end, { desc = "Close the Traverser dashboard" })

	vim.api.nvim_create_user_command("TraverserAddNode", function()
		traces.toggle_here()
	end, { desc = "Add/remove a trace node at cursor" })

	vim.api.nvim_create_user_command("TraverserTree", function()
		traces.open_tree()
	end, { desc = "Toggle the trace tree" })

	vim.api.nvim_create_user_command("TraverserNewTrace", function(opts)
		traces.new_trace(opts.args)
	end, { nargs = "?", complete = "file", desc = "Create a new trace" })

	vim.api.nvim_create_user_command("TraverserSwitchTrace", function()
		picker.switch_trace_picker()
	end, { desc = "Pick a trace to switch to" })

	vim.api.nvim_create_user_command("TraverserEdit", function()
		traces.open_editor()
	end, { desc = "Floating editor to reorder trace items" })

	vim.api.nvim_create_user_command("TraverserJump", function(opts)
		if opts.args == "" then
			traces.prompt_and_jump()
		else
			traces.jump_to_tag(opts.args)
		end
	end, {
		nargs = "?",
		complete = function(_, line)
			local lword = line:match("%S+$") or ""
			local t = {}
			local trace = traces.get_active_trace()
			if trace then
				for _, it in ipairs(trace.items) do
					table.insert(t, it.tag:sub(2, -2))
				end
			end
			return vim.tbl_filter(function(x)
				return x:match("^" .. lword)
			end, t)
		end,
		desc = "Jump to a trace tag",
	})

	-- Pane focus commands
	vim.api.nvim_create_user_command("TraverserFocusSymbols", function()
		edgy.focus("s")
	end, { desc = "Focus the Symbols pane" })

	vim.api.nvim_create_user_command("TraverserFocusDiagnostics", function()
		edgy.focus("d")
	end, { desc = "Focus the Diagnostics pane" })

	vim.api.nvim_create_user_command("TraverserFocusReferences", function()
		edgy.focus("lr")
	end, { desc = "Focus the References pane" })

	vim.api.nvim_create_user_command("TraverserFocusIncoming", function()
		edgy.focus("i")
	end, { desc = "Focus the Incoming Calls pane" })

	vim.api.nvim_create_user_command("TraverserFocusOutgoing", function()
		edgy.focus("o")
	end, { desc = "Focus the Outgoing Calls pane" })

	-- Pane maximize commands
	vim.api.nvim_create_user_command("TraverserMaximizeSymbols", function()
		edgy.maximize("s")
	end, { desc = "Toggle-maximize the Symbols pane" })

	vim.api.nvim_create_user_command("TraverserMaximizeDiagnostics", function()
		edgy.maximize("d")
	end, { desc = "Toggle-maximize the Diagnostics pane" })

	vim.api.nvim_create_user_command("TraverserMaximizeReferences", function()
		edgy.maximize("lr")
	end, { desc = "Toggle-maximize the References pane" })

	vim.api.nvim_create_user_command("TraverserMaximizeIncoming", function()
		edgy.maximize("i")
	end, { desc = "Toggle-maximize the Incoming Calls pane" })

	vim.api.nvim_create_user_command("TraverserMaximizeOutgoing", function()
		edgy.maximize("o")
	end, { desc = "Toggle-maximize the Outgoing Calls pane" })

	-- Symbol pickers (uses configured backend: telescope or snacks)
	vim.api.nvim_create_user_command("TraverserSymbolsBuf", function()
		picker.symbols_picker("buf")
	end, { desc = "Buffer symbols with peek" })

	vim.api.nvim_create_user_command("TraverserSymbolsWorkspace", function()
		picker.symbols_picker("ws")
	end, { desc = "Workspace symbols with peek" })

	-- Trouble navigation
	local trouble_mod = require("traverser.trouble")

	vim.api.nvim_create_user_command("TraverserNext", function()
		trouble_mod.jump_next()
	end, { desc = "Next item in last-used Trouble list" })

	vim.api.nvim_create_user_command("TraverserPrev", function()
		trouble_mod.jump_prev()
	end, { desc = "Prev item in last-used Trouble list" })
end

return M
