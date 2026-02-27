-- traverser/picker/init.lua – Backend dispatcher
--
-- Resolves which picker backend to use ("telescope" | "snacks" | "auto")
-- and delegates to the appropriate module.
-- Both backends implement the same interface:
--   .symbols_picker(kind)    -- kind = "buf" | "ws"
--   .switch_trace_picker()
--   .make_peek(code_win_id)  -- returns an action/callback
--   .setup(config)

local M = {}

---@type "telescope"|"snacks"|nil
local resolved_backend = nil

--- Detect which picker is available
---@return "snacks"|"telescope"
local function detect()
	-- Prefer snacks if loaded / available
	local snacks_ok = pcall(require, "snacks")
	if snacks_ok then
		-- Check that the picker sub-module exists
		local picker_ok = pcall(function()
			return Snacks and Snacks.picker
		end)
		if picker_ok then
			return "snacks"
		end
	end

	local tele_ok = pcall(require, "telescope")
	if tele_ok then
		return "telescope"
	end

	-- Fallback – telescope is the historical default
	return "telescope"
end

--- Resolve the backend module once and cache it
---@param config? TraverserConfig
---@return table backend module
function M.get(config)
	if not resolved_backend then
		local setting = config and config.picker or "auto"
		if setting == "auto" then
			resolved_backend = detect()
		else
			resolved_backend = setting
		end
	end

	if resolved_backend == "snacks" then
		return require("traverser.picker.snacks")
	else
		return require("traverser.picker.telescope")
	end
end

--- Which backend is active?
---@return string
function M.backend()
	return resolved_backend or "unknown"
end

--- Forward setup to the resolved backend
function M.setup(config)
	M.get(config).setup(config)
end

--- Forward symbols_picker
function M.symbols_picker(kind)
	M.get().symbols_picker(kind)
end

--- Forward switch_trace_picker
function M.switch_trace_picker()
	M.get().switch_trace_picker()
end

return M
