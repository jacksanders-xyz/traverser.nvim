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
				desc = "Jump to symbol, then list refs inside this function",
				action = function(view)
					local current_line = vim.fn.line(".")
					require("trouble").cancel()
					vim.schedule(function()
						local function get_func_range_ts()
							local ok, tsu = pcall(require, "nvim-treesitter.ts_utils")
							if not ok then
								return
							end

							local node = tsu.get_node_at_cursor()
							while
								node
								and not vim.tbl_contains({
									"function_definition",
									"function_declaration",
									"method_declaration",
									"function",
									"method",
								}, node:type())
							do
								node = node:parent()
							end
							if not node then
								return
							end
							local sr, _, er, _ = node:range()
							return sr + 1, er + 1
						end

						local start_l, end_l = get_func_range_ts()
						if not start_l then
							vim.notify("Couldn't detect function scope (Treesitter)", vim.log.levels.WARN)
							return
						end
						local parent_file = vim.api.nvim_buf_get_name(0)

						view:jump()
						require("trouble").open({
							mode = "lsp_references",
							open_no_results = true,
							keys = {
								["<C-e>"] = {
									desc = "reset cursor to outgoing",
									action = function(ref_view)
										ref_view:close()
										vim.defer_fn(function()
											vim.api.nvim_feedkeys(
												vim.api.nvim_replace_termcodes("<C-o>", true, false, true),
												"n",
												false
											)
											vim.defer_fn(function()
												for _, win in ipairs(vim.api.nvim_list_wins()) do
													local t = vim.w[win].trouble
													if t and t.type == "split" and t.relative == "editor" then
														if
															t.mode == "lsp_outgoing_calls"
															or t.mode == "traverser_outgoing"
														then
															vim.api.nvim_set_current_win(win)
															break
														end
													end
												end
												vim.defer_fn(function()
													vim.api.nvim_win_set_cursor(0, { current_line, 0 })
												end, 180)
											end, 90)
										end, 10)
									end,
								},
							},
							filter = function(items)
								return vim.tbl_filter(function(item)
									local same_file = (
										item.filename
										and vim.fn.fnamemodify(item.filename, ":p")
											== vim.fn.fnamemodify(parent_file, ":p")
									)
										or (item.bufnr and vim.api.nvim_buf_get_name(item.bufnr) == parent_file)

									local l = item.pos[1]
									local in_range = l and l >= start_l and l <= end_l

									return same_file and in_range
								end, items)
							end,
						})
						require("trouble").first({ mode = "lsp_references" })
						require("trouble").focus({ mode = "lsp_references" })
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
