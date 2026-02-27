-- traverser/traces.lua – extmarks -> in-memory store -> quickfix -> Trouble
local M = {}
local ns = vim.api.nvim_create_namespace("traverser")

------------------------------------------------------------
-- 0.  State & persistence helpers
------------------------------------------------------------
local store = {
	active = 1,
	traces = { { name = "Trace 1", items = {} } },
}

local data_dir = vim.fn.stdpath("data") .. "/traverser"
local fname = data_dir .. "/" .. vim.fn.sha256(vim.fn.getcwd()) .. ".json"

local function save_state()
	vim.fn.mkdir(data_dir, "p")
	local ok, msg = pcall(vim.fn.writefile, { vim.fn.json_encode(store) }, fname)
	if not ok then
		vim.notify("Traverser save failed: " .. msg, vim.log.levels.ERROR)
	end
end

local function load_state()
	if vim.fn.filereadable(fname) == 1 then
		local ok, t = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(fname), "\n"))
		if ok and t then
			store = t
		end
	end
end

------------------------------------------------------------
-- Public state accessors
------------------------------------------------------------
function M.get_store()
	return store
end

function M.get_active_trace()
	return store.traces[store.active]
end

function M.save()
	save_state()
end

------------------------------------------------------------
-- Tag helpers
------------------------------------------------------------
local function idx_to_tag(n)
	local s = ""
	while n > 0 do
		local r = (n - 1) % 26
		s = string.char(97 + r) .. s
		n = math.floor((n - 1) / 26)
	end
	return ("[%s]"):format(s)
end

local function next_tag(trace)
	return idx_to_tag(#trace.items + 1)
end

------------------------------------------------------------
-- Convert current trace -> quickfix list
------------------------------------------------------------
local function trace_to_qf(trace)
	local qf = {}
	for _, it in ipairs(trace.items) do
		table.insert(qf, {
			bufnr = it.bufnr,
			filename = it.filename,
			lnum = it.lnum,
			col = 1,
			text = ("%s %s"):format(it.tag, it.text),
		})
	end
	return qf
end

function M.rebuild_qf()
	if store.traces[store.active] then
		vim.fn.setqflist(trace_to_qf(store.traces[store.active]), "r")
	end
end

------------------------------------------------------------
-- Toggle mark at cursor
------------------------------------------------------------
function M.toggle_here()
	if not store.traces[store.active] then
		vim.notify("Traverser: no active trace -- create one with :TraverserNewTrace", vim.log.levels.WARN)
		return
	end

	local bufnr = 0
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local mark = vim.api.nvim_buf_get_extmarks(bufnr, ns, { row, 0 }, { row, -1 }, {})

	if #mark > 0 then
		vim.api.nvim_buf_del_extmark(bufnr, ns, mark[1][1])
		local items = store.traces[store.active].items
		for i = #items, 1, -1 do
			if items[i].bufnr == bufnr and items[i].lnum == row + 1 then
				table.remove(items, i)
			end
		end
	else
		vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {})
		local trace = store.traces[store.active]
		table.insert(trace.items, {
			tag = next_tag(trace),
			bufnr = bufnr,
			filename = vim.api.nvim_buf_get_name(bufnr),
			lnum = row + 1,
			text = vim.trim(vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]),
		})
	end

	save_state()
	M.rebuild_qf()
	pcall(function()
		require("trouble").refresh("traverser_tree")
	end)
end

------------------------------------------------------------
-- New trace
------------------------------------------------------------
function M.new_trace(name)
	name = (name and name ~= "") and name or ("Trace " .. (#store.traces + 1))
	table.insert(store.traces, { name = name, items = {} })
	store.active = #store.traces
	save_state()
	M.rebuild_qf()
	pcall(function()
		require("trouble").refresh("traverser_tree")
	end)
	vim.notify("Traverser: created " .. name)
end

------------------------------------------------------------
-- Jump to tag
------------------------------------------------------------
function M.jump_to_tag(tag)
	tag = tag:lower()
	local trace = store.traces[store.active]
	if not trace then
		return
	end

	for _, it in ipairs(trace.items) do
		if it.tag:sub(2, -2):lower() == tag then
			local bufnr = (it.bufnr and it.bufnr > 0) and it.bufnr or vim.fn.bufadd(it.filename)
			vim.fn.bufload(bufnr)
			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { it.lnum, (it.col or 1) - 1 })
			vim.cmd("normal! zv")
			return
		end
	end
	vim.notify("Traverser: tag [" .. tag .. "] not found", vim.log.levels.WARN)
end

------------------------------------------------------------
-- Prompt and jump (single keystroke for <= 26 items)
------------------------------------------------------------
function M.prompt_and_jump()
	local trace = store.traces[store.active]
	if not trace then
		return
	end

	if #trace.items <= 26 then
		local ch = vim.fn.getcharstr()
		if ch and ch ~= "" then
			M.jump_to_tag(ch)
		end
		return
	end

	vim.ui.input({ prompt = "Jump to tag: " }, function(input)
		if input and input ~= "" then
			M.jump_to_tag(input)
		end
	end)
end

------------------------------------------------------------
-- Floating editor for reordering trace items
------------------------------------------------------------
function M.open_editor()
	local trace = store.traces[store.active]
	if not trace or #trace.items == 0 then
		vim.notify("Traverser: nothing to edit", vim.log.levels.WARN)
		return
	end

	local lines = vim.tbl_map(function(it)
		return ("%s %s"):format(it.tag, it.text)
	end, trace.items)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "traverser_edit"

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = math.max(30, math.floor(vim.o.columns * 0.4)),
		height = math.max(3, #lines + 2),
		row = math.floor((vim.o.lines - #lines) / 2) - 1,
		col = math.floor(vim.o.columns / 2) - 15,
		border = "rounded",
	})

	local function move(delta)
		local lnum = vim.api.nvim_win_get_cursor(win)[1]
		local dst = lnum + delta
		if dst < 1 or dst > #lines then
			return
		end
		lines[lnum], lines[dst] = lines[dst], lines[lnum]
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_win_set_cursor(win, { dst, 0 })
	end

	vim.keymap.set("n", "<C-k>", function()
		move(-1)
	end, { buffer = buf })
	vim.keymap.set("n", "<C-j>", function()
		move(1)
	end, { buffer = buf })

	vim.keymap.set("n", "q", function()
		local new = {}
		for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
			local tag = line:match("^%[(.-)%]%s+(.*)$")
			for _, it in ipairs(trace.items) do
				if it.tag:sub(2, -2) == tag then
					table.insert(new, it)
					break
				end
			end
		end
		trace.items = new
		M.rebuild_qf()
		save_state()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })
end

------------------------------------------------------------
-- Delete trace by index
------------------------------------------------------------
function M.delete_trace(idx)
	table.remove(store.traces, idx)
	if store.active > #store.traces then
		store.active = math.max(1, #store.traces)
	end
	save_state()
end

------------------------------------------------------------
-- Rename trace
------------------------------------------------------------
function M.rename_trace(idx, new_name)
	if store.traces[idx] then
		store.traces[idx].name = new_name
		save_state()
		M.rebuild_qf()
		pcall(function()
			require("trouble").refresh("traverser_tree")
		end)
	end
end

------------------------------------------------------------
-- Switch active trace
------------------------------------------------------------
function M.switch_trace(idx)
	store.active = idx
	M.rebuild_qf()
	pcall(function()
		require("trouble").open("traverser_tree")
	end)
end

------------------------------------------------------------
-- Open trace tree
------------------------------------------------------------
function M.open_tree()
	if #store.traces == 0 then
		vim.notify("Traverser: no trace yet -- create one with :TraverserNewTrace", vim.log.levels.WARN)
		return
	end

	local trace = store.traces[store.active]
	if #trace.items == 0 then
		vim.notify("Traverser: active trace is empty -- add nodes with :TraverserAddNode", vim.log.levels.WARN)
		return
	end

	M.rebuild_qf()
	require("trouble").toggle("traverser_tree")
end

------------------------------------------------------------
-- Setup
------------------------------------------------------------
function M.setup(_config)
	load_state()
	vim.api.nvim_create_autocmd("VimLeavePre", { callback = save_state })
end

return M
