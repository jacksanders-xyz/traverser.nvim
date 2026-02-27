-- plugin/traverser.lua – Neovim will auto-source this file.
-- We do NOT call setup() here; that's the user's job via lazy.nvim or similar.
-- This file just ensures the command exists before setup, so the user can
-- do `:TraverserToggle` even if they forgot to call setup().

if vim.g.loaded_traverser then
	return
end
vim.g.loaded_traverser = true

-- Deferred command: if someone calls :TraverserToggle before setup(),
-- auto-call setup() with defaults first.
vim.api.nvim_create_user_command("TraverserToggle", function()
	require("traverser").setup()
	require("traverser.dashboard").toggle()
end, { desc = "Toggle the Traverser dashboard (auto-setup)" })
