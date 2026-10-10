---@class BufSwitchKeys
---@field back string|false move toward older buffers, takes a count
---@field forward string|false move toward newer buffers, takes a count
---@field jump (string|false)[]|false the n-th key goes to entry n of the bar
---@field remove (string|false)[]|false the n-th key removes entry n from the history
---@field remove_back string|false remove the current entry and open the older one
---@field remove_forward string|false remove the current entry and open the newer one
---@field add string|false record the current buffer while paused
---@field toggle_pause string|false
---@field clear string|false
---@field inspect string|false print the raw history

---@class BufSwitchExclude
---@field buftypes string[] exact 'buftype' values
---@field filetypes string[] Lua patterns matched against 'filetype'
---@field names string[] Lua patterns matched against the buffer name

---@class BufSwitchIgnore
---@field filetypes string[] Lua patterns matched against 'filetype'
---@field names string[] Lua patterns matched against the buffer name
---@field diffview_tab boolean also stay out of every window in a diffview.nvim tab

---@class BufSwitchConfig
---@field start_paused boolean
---@field winbar boolean draw the bar in the global winbar
---@field compact_after integer
---@field debug boolean
---@field keys BufSwitchKeys|false
---@field exclude BufSwitchExclude
---@field ignore BufSwitchIgnore

local M = {}

---@type BufSwitchConfig
M.defaults = {
	start_paused = false,
	winbar = true,
	-- Past this many entries the unselected ones shrink to their number and icon
	compact_after = 7,
	debug = false,
	keys = {
		back = "<>",
		forward = "><",
		jump = { "<A-a>", "<A-s>", "<A-d>", "<A-f>", "<A-g>", "<A-h>", "<A-j>", "<A-k>", "<A-l>" },
		remove = {
			"<leader>j1", "<leader>j2", "<leader>j3", "<leader>j4", "<leader>j5",
			"<leader>j6", "<leader>j7", "<leader>j8", "<leader>j9",
		},
		remove_back = "<<",
		remove_forward = ">>",
		add = "<leader>jj",
		toggle_pause = "<leader>jl",
		clear = "<leader>jk",
		inspect = "<leader>bb",
	},
	-- Never recorded, but entering them still counts as leaving the history
	exclude = {
		buftypes = { "nofile" },
		filetypes = { "^oil$", "harpoon", "TelescopePrompt" },
		names = { "^oil://", "Neogit" },
	},
	-- Tool UIs, skipped entirely: neogit (with the diffview tab it opens for diffs) and the avante sidebar
	ignore = {
		filetypes = { "^Neogit", "^Diffview", "^Avante" },
		names = { "^neogit://", "^diffview://" },
		diffview_tab = true,
	},
}

---@type BufSwitchConfig
M.options = vim.deepcopy(M.defaults)

---Option tables merge key by key, lists and plain values are replaced whole
---@param default any
---@param override any
---@param path string the option being merged, for the unknown option warning
---@return any
local function merge(default, override, path)
	if override == nil then
		return vim.deepcopy(default)
	end
	if type(default) ~= "table" or vim.islist(default) or type(override) ~= "table" then
		return override
	end

	local merged = {}
	for key, value in pairs(default) do
		merged[key] = merge(value, override[key], path .. key .. ".")
	end
	for key in pairs(override) do
		if default[key] == nil then
			vim.notify("bufswitch: unknown option " .. path .. key, vim.log.levels.WARN)
		end
	end
	return merged
end

---@param opts? table
---@return BufSwitchConfig
function M.setup(opts)
	M.options = merge(M.defaults, opts or {}, "")
	return M.options
end

return M
