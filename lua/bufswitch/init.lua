local config = require("bufswitch.config")
local validators = require("bufswitch.validation")
local mover = require("bufswitch.buffer_entries_move")
local buffer_history_util = require("bufswitch.buffer_history_utils")
local on_attach_handler = require("bufswitch.on_attach")
local ui = require("bufswitch.ui")

---@class BufferHistory
---@field debug boolean
---@field history BufferEntry[] oldest first
---@field current_index integer index of the entry being viewed
---@field is_viewing boolean the next BufEnter comes from our own move
---@field paused boolean new buffers are not recorded
---@field is_outside boolean the current buffer is not in the history (tracked while paused)
---@field on_attach BufferHistoryOnAttachHandler
---@field utils BufferHistoryUtils
---@field mover BufferHistoryMover

local M = {}

---The history, set by setup()
---@type BufferHistory?
M.history = nil

---@param opts BufSwitchConfig
---@return BufferHistory
local function new_history(opts)
	return {
		debug = opts.debug,
		history = {},
		current_index = 0,
		is_viewing = false,
		on_attach = on_attach_handler,
		utils = buffer_history_util,
		mover = mover,
		paused = opts.start_paused,
		is_outside = false,
	}
end

---@param bufnr integer
---@return boolean
local function in_tool_window(bufnr)
	return validators.is_ignored_buffer(bufnr) or validators.is_in_diffview_tab()
end

---Wraps fn into a public action on the history, which redraws the bar afterwards
---@param fn fun(history: BufferHistory, ...): any
---@param moves? boolean switches buffers, so it has to stay out of tool windows
---@return fun(...): any
local function action(fn, moves)
	return function(...)
		local history = M.history
		if not history then
			vim.notify("bufswitch: call require('bufswitch').setup() first", vim.log.levels.ERROR)
			return false
		end

		-- Switching buffers inside neogit, diffview or avante windows would replace their own
		if moves and in_tool_window(vim.api.nvim_get_current_buf()) then
			vim.print("Buffer history: not switching buffers in this window")
			return false
		end

		local result = fn(history, ...)
		-- Every action redraws the bar: a move that fails fires no BufEnter to do it
		ui.update(history)
		return result
	end
end

------ SCROLL BETWEEN --------

---Moves `count` (default 1) entries toward older buffers, wrapping from the oldest to the newest
M.back = action(function(history, count)
	return history.mover.go_back(history, math.max(count or 1, 1))
end, true)

---Moves `count` (default 1) entries toward newer buffers
M.forward = action(function(history, count)
	return history.mover.go_forward(history, math.max(count or 1, 1))
end, true)

------ QUICK SWITCH --------

---Opens entry `number` of the bar, 1 being the most recent buffer
M.jump = action(function(history, number)
	return history.mover.go_to_number(history, number)
end, true)

---Removes entry `number` of the bar from the history, staying on the current buffer
M.remove = action(function(history, number)
	history.utils.delete_at_target(history, number)
end)

---Removes the current entry and opens the older one
M.remove_back = action(function(history)
	history.utils.remove_current(history, false)
end, true)

---Removes the current entry and opens the newer one
M.remove_forward = action(function(history)
	history.utils.remove_current(history, true)
end, true)

------ MANAGE HISTORY --------

---Records the current buffer while paused
M.add = action(function(history)
	if history.utils.get_matching_entry_idx(history, nil, vim.api.nvim_get_current_buf()) then
		vim.notify("Buffer already in history")
		return false
	end

	if not (history.paused or history.is_viewing) then
		vim.notify("Cannot access in unpaused mode or viewing mode")
		return false
	end

	if history.on_attach.on_attach(history, true) then -- bypasses the pause
		vim.notify("Added buffer to the end of list!")
		return true
	end
	vim.notify("This buffer can't be added to the history")
	return false
end)

---Stops or resumes recording new buffers
M.toggle_pause = action(function(history)
	history.utils.toggle_pause(history)
end)

---Empties the history and starts again from the current buffer
M.clear = action(function(history)
	history.utils.clear(history)
end)

---Prints the raw history entries
M.inspect = action(function(history)
	vim.notify(vim.inspect(history.history))
end)

---The bar as a statusline string, for use outside the winbar (see `winbar = false`)
---@return string
function M.render()
	return M.history and ui.render(M.history) or ""
end

------ COMMAND --------

---@type table<string, fun(arg?: string)>
local subcommands = {
	back = function(arg) M.back(tonumber(arg or "")) end,
	forward = function(arg) M.forward(tonumber(arg or "")) end,
	jump = function(arg)
		local number = tonumber(arg or "")
		if not number then return vim.notify("Usage: :BufSwitch jump {number}", vim.log.levels.ERROR) end
		M.jump(number)
	end,
	remove = function(arg)
		local number = tonumber(arg or "")
		if not number then return vim.notify("Usage: :BufSwitch remove {number}", vim.log.levels.ERROR) end
		M.remove(number)
	end,
	remove_back = function() M.remove_back() end,
	remove_forward = function() M.remove_forward() end,
	add = function() M.add() end,
	toggle_pause = function() M.toggle_pause() end,
	clear = function() M.clear() end,
	inspect = function() M.inspect() end,
}

local function create_command()
	vim.api.nvim_create_user_command("BufSwitch", function(cmd)
		local subcommand = subcommands[cmd.fargs[1]]
		if not subcommand then
			vim.notify("bufswitch: unknown subcommand " .. cmd.fargs[1], vim.log.levels.ERROR)
			return
		end
		subcommand(cmd.fargs[2])
	end, {
		nargs = "+",
		desc = "Buffer history",
		complete = function(arglead, cmdline)
			-- Only the subcommand itself completes
			if cmdline:match("^%S+%s+%S+%s") then
				return {}
			end
			return vim.tbl_filter(function(name)
				return vim.startswith(name, arglead)
			end, vim.tbl_keys(subcommands))
		end,
	})
end

------ KEYMAPS --------

---@param keys BufSwitchKeys|false
local function set_keymaps(keys)
	if not keys then
		return
	end

	local function map(lhs, desc, fn)
		if lhs then
			vim.keymap.set("n", lhs, fn, { desc = desc })
		end
	end

	map(keys.back, "move back a buffer in history", function() M.back(vim.v.count) end)
	map(keys.forward, "move forward a buffer in history", function() M.forward(vim.v.count) end)

	for number, lhs in ipairs(keys.jump or {}) do
		map(lhs, "go to buffer " .. number .. " in history", function() M.jump(number) end)
	end
	for number, lhs in ipairs(keys.remove or {}) do
		map(lhs, "remove buffer " .. number .. " from history", function() M.remove(number) end)
	end

	map(keys.remove_back, "Removes the current buffer and moves to the older one", M.remove_back)
	map(keys.remove_forward, "Removes the current buffer and moves to the newer one", M.remove_forward)
	map(keys.add, "Adds the current buffer while paused", M.add)
	map(keys.toggle_pause, "Toggle pausing the buffer history", M.toggle_pause)
	map(keys.clear, "Clear buffer history", M.clear)
	map(keys.inspect, "Debug buffer history", M.inspect)
end

------ SETUP --------

---@param opts? table see config.lua for the options
---@return BufferHistory
function M.setup(opts)
	local options = config.setup(opts)
	local buffer_history = new_history(options)
	M.history = buffer_history

	if buffer_history.debug then vim.print(vim.inspect(buffer_history)) end
	if buffer_history.debug and buffer_history.paused then
		vim.notify("Buffer history started in paused mode")
	end

	local group = vim.api.nvim_create_augroup("BufSwitch", { clear = true })

	-- keep it robust with lazy.nvim + colorscheme changes
	local function refresh_highlights()
		ui.set_highlights()
		ui.update(buffer_history)
	end
	vim.api.nvim_create_autocmd("User", { group = group, pattern = "VeryLazy", callback = refresh_highlights })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = refresh_highlights })
	ui.set_highlights()

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(args)
			-- Leave the history, and the winbars neogit/avante draw, untouched
			if in_tool_window(args.buf) then
				return
			end
			buffer_history.on_attach.on_attach(buffer_history)
			ui.update(buffer_history)
		end,
	})

	-- Start from the buffer already open, which matters when the plugin loads late (e.g. on VeryLazy)
	buffer_history.on_attach.on_attach(buffer_history)
	ui.update(buffer_history)

	set_keymaps(options.keys)
	create_command()

	return buffer_history
end

return M
