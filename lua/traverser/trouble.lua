-- traverser/trouble.lua – Trouble mode definitions and keybindings
local M = {}



function M.setup(config)
	local drawer_size = config.drawer_size or 56

	-- Helper: detect library paths
	local function is_library(item)
		local f = item.filename or ""
		return f:match("^/usr")
			or f:match("/pkg/mod/")
			or f:match("/vendor/")
			or f:match("node_modules")
	end

	require("trouble").setup({
		keys = {
			s = false,
			S = {
				action = function(view)
					local f = view:get_filter("severity")
					local severity = ((f and f.filter.severity or 0) + 1) % 5
					view:filter({ severity = severity }, {
						id = "severity",
						template = "{hl:Title}Filter:{hl} {severity}",
						del = severity == 0,
					})
				end,
				desc = "Toggle Severity Filter",
			},
			["L"] = {
				desc = "Toggle library filter (Outgoing pane)",
				action = function(view)
					local wm = vim.w.trouble and vim.w.trouble.mode
					if wm ~= "traverser_outgoing" and view.mode ~= "lsp_outgoing_calls" then
						vim.api.nvim_echo({ { "L only in Outgoing pane", "WarningMsg" } }, false, {})
						return
					end

					if vim.w.lib_filter_on then
						view:filter(nil, { id = "libtoggle", del = true })
						vim.w.lib_filter_on = false
					else
						view:filter(function(item)
							return not is_library(item)
						end, {
							id = "libtoggle",
							template = "{hl:Title}Filter:{hl} hide-libs",
						})
						vim.w.lib_filter_on = true
					end

					require("trouble").refresh({ mode = view.mode })
				end,
			},
			["<c-r>"] = {
				desc = "Scoped refs: quickfix list of references within the caller's function",
				action = function(view)
					local loc = view:at()
					local item = loc.item
					if not item then
						vim.notify("No item under cursor", vim.log.levels.WARN)
						return
					end

					local def_file = item.filename
					local def_line = item.pos and item.pos[1] or nil

					-- Get caller's file + function scope from the code window
					local caller_file, start_l, end_l, code_win
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						local bufnr = vim.api.nvim_win_get_buf(win)
						local cfg = vim.api.nvim_win_get_config(win)
						local t = vim.w[win].trouble
						local bt = vim.bo[bufnr].buftype
						local ft = vim.bo[bufnr].filetype

						if not t and cfg.relative == "" and bt == "" and ft ~= "trouble" then
							code_win = win
							caller_file = vim.api.nvim_buf_get_name(bufnr)

							local result = vim.api.nvim_win_call(win, function()
								local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
								if ok_parser and parser then
									parser:parse()
								end
								local ts_node = vim.treesitter.get_node()
								if not ts_node then
									return nil
								end
								local func_types = {
									"function_definition",
									"function_declaration",
									"method_declaration",
									"func_literal",
									"function",
									"method",
								}
								while ts_node and not vim.tbl_contains(func_types, ts_node:type()) do
									ts_node = ts_node:parent()
								end
								if not ts_node then
									return nil
								end
								local sr, _, er, _ = ts_node:range()
								return { sr + 1, er + 1 }
							end)
							if result then
								start_l = result[1]
								end_l = result[2]
							end
							break
						end
					end

					if not start_l then
						vim.notify("Couldn't detect function scope (Treesitter). Navigate to the caller's file first.", vim.log.levels.WARN)
						return
					end

					-- Jump to the definition to position cursor for LSP references request
					view:jump()

					vim.schedule(function()
						local clients = vim.lsp.get_clients({ bufnr = 0 })
						local encoding = clients[1] and clients[1].offset_encoding or "utf-16"
						local params = vim.lsp.util.make_position_params(0, encoding)
						params.context = { includeDeclaration = false }

						vim.lsp.buf_request(0, "textDocument/references", params, function(err, result)
							if err or not result or #result == 0 then
								vim.notify("No references found", vim.log.levels.INFO)
								return
							end

							-- Filter to caller's scope, build quickfix entries
							local qf_items = {}
							for _, ref in ipairs(result) do
								local ref_file = vim.uri_to_fname(ref.uri)
								local ref_line = ref.range.start.line + 1
								local ref_col = ref.range.start.character + 1

								local is_definition = def_line
									and vim.fn.fnamemodify(ref_file, ":p") == vim.fn.fnamemodify(def_file, ":p")
									and ref_line == def_line

								if not is_definition then
									local same_file = vim.fn.fnamemodify(ref_file, ":p")
										== vim.fn.fnamemodify(caller_file, ":p")
									local in_scope = ref_line >= start_l and ref_line <= end_l

									if same_file and in_scope then
										-- Read the line text for display
										local bufnr = vim.fn.bufadd(ref_file)
										vim.fn.bufload(bufnr)
										local lines = vim.api.nvim_buf_get_lines(bufnr, ref_line - 1, ref_line, false)
										local text = lines[1] and vim.trim(lines[1]) or ""

										table.insert(qf_items, {
											filename = ref_file,
											lnum = ref_line,
											col = ref_col,
											text = text,
										})
									end
								end
							end

							if #qf_items == 0 then
								vim.notify("No references in current function scope", vim.log.levels.INFO)
								return
							end

							-- If only 1 reference, jump directly
							if #qf_items == 1 then
								if code_win and vim.api.nvim_win_is_valid(code_win) then
									vim.api.nvim_set_current_win(code_win)
								end
								local qf = qf_items[1]
								local bufnr = vim.fn.bufadd(qf.filename)
								vim.fn.bufload(bufnr)
								vim.api.nvim_win_set_buf(0, bufnr)
								vim.api.nvim_win_set_cursor(0, { qf.lnum, qf.col - 1 })
								vim.cmd("normal! zz")
								return
							end

							-- Multiple: populate quickfix and jump to first
							vim.fn.setqflist(qf_items, "r")
							vim.fn.setqflist({}, "a", { title = "Scoped refs (in caller)" })

							if code_win and vim.api.nvim_win_is_valid(code_win) then
								vim.api.nvim_set_current_win(code_win)
							end
							vim.cmd("cfirst")
						end)
					end)
				end,
			},
		},
		modes = {
			traverser_lsp = {
				sections = {
					"lsp_declarations",
					"lsp_implementations",
					"lsp_references",
					"lsp_type_definitions",
				},
				title = "  Refs / Defs",
				follow = true,
				auto_refresh = true,
				params = { include_declaration = false },
				pinned = false,
				preview = { type = "main" },
				include_current = true,
				open_no_results = true,
				lsp_base = {
					params = { include_current = true },
				},
				win = {
					type = "split",
					position = "bottom",
					size = 80,
				},
			},
			traverser_symbols = {
				mode = "symbols",
				title = "  Symbols",
				follow = true,
				open_no_results = true,
				win = { type = "split", position = "left", size = drawer_size },
			},
			traverser_diagnostics = {
				mode = "diagnostics",
				title = "  Diagnostics",
				open_no_results = true,
				follow = true,
				win = {
					type = "split",
					position = "left",
					height = 6,
				},
			},
			traverser_incoming = {
				mode = "lsp_incoming_calls",
				title = "  Incoming",
				open_no_results = true,
				follow = true,
				win = { type = "split", position = "right", height = 6 },
			},
			traverser_outgoing = {
				mode = "lsp_outgoing_calls",
				title = "  Outgoing",
				open_no_results = true,
				auto_preview = false,
				follow = true,
				sort = { "pos" },
				preview = { type = "main" },
				win = { type = "split", position = "right", height = 6 },
			},
			traverser_tree = {
				mode = "quickfix",
				title = "  Trace",
				groups = false,
				sort = { "text" },
				follow = true,
				win = { type = "split", position = "bottom", height = 8 },
			},
		},
	})

	------------------------------------------------------------------------
	-- Trouble navigation helper: remember last trouble mode, jump next/prev
	------------------------------------------------------------------------
	local trouble = require("trouble")
	local last_trouble_mode = nil

	vim.api.nvim_create_autocmd("WinEnter", {
		desc = "Traverser: remember last Trouble mode",
		callback = function()
			local t = vim.w.trouble
			if t and t.mode then
				last_trouble_mode = t.mode
			end
		end,
	})

	-- Expose jump helpers for commands/keymaps
	function M.jump_next()
		local opts = { skip_groups = true, jump = true }
		if last_trouble_mode and trouble.is_open(last_trouble_mode) then
			opts.mode = last_trouble_mode
		end
		trouble.next(opts)
	end

	function M.jump_prev()
		local opts = { skip_groups = true, jump = true }
		if last_trouble_mode and trouble.is_open(last_trouble_mode) then
			opts.mode = last_trouble_mode
		end
		trouble.prev(opts)
	end

	------------------------------------------------------------------------
	-- Suppress noisy LSP handlers (Trouble handles these itself)
	------------------------------------------------------------------------
	vim.lsp.handlers["textDocument/references"] =
		vim.lsp.with(vim.lsp.handlers.locations, { loclist = true, open = false })
	vim.lsp.handlers["callHierarchy/incomingCalls"] = function() end
	vim.lsp.handlers["callHierarchy/outgoingCalls"] = function() end
end

return M
