local config = require("bufswitch.config")

---@class BufferEntryValidator
local BufferEntryValidator = {}

---@param bufnr integer
---@param filetypes string[]
---@param names string[]
---@return boolean
local function matches_any(bufnr, filetypes, names)
	local ft = vim.bo[bufnr].filetype
	for _, pattern in ipairs(filetypes) do
		if ft:match(pattern) then return true end
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	for _, pattern in ipairs(names) do
		if name:match(pattern) then return true end
	end
	return false
end

---@param bufnr integer
---@return boolean is_ignored
--- Buffers from tools that should never enter or move the history
local function is_ignored_buffer(bufnr)
	local ignore = config.options.ignore
	return vim.api.nvim_buf_is_valid(bufnr) and matches_any(bufnr, ignore.filetypes, ignore.names)
end

---@return boolean in_diffview
--- The working-tree side of a diff is a normal file buffer, so only the tab tells it apart.
--- Depends on the current tab, so keep it out of entry validation.
local function is_in_diffview_tab()
	if not config.options.ignore.diffview_tab then
		return false
	end
	local diffview = package.loaded["diffview.lib"]
	return diffview ~= nil and diffview.get_current_view() ~= nil
end

---@param self BufferEntry
---@return boolean is_disallowed
function BufferEntryValidator:check_disallowed_buffers()
	-- A wiped buffer can't be switched back to
	if not vim.api.nvim_buf_is_valid(self.bufnr) then
		return true
	end

	local exclude = config.options.exclude
	if vim.tbl_contains(exclude.buftypes, vim.bo[self.bufnr].buftype) or not vim.bo[self.bufnr].buflisted then
		return true
	end

	return matches_any(self.bufnr, exclude.filetypes, exclude.names) or is_ignored_buffer(self.bufnr)
end

---@param self BufferEntry
---@param history BufferHistory
---@return boolean is_valid
function BufferEntryValidator:validate(history)
	if self.validator.check_disallowed_buffers(self) then
		if history.debug then vim.print("[validate] disallowed: " .. self.filepath) end
		return false
	end

	-- The file can be renamed or not written yet, so follow the buffer's name
	local name = vim.api.nvim_buf_get_name(self.bufnr)
	if name == "" then
		return false
	end
	self.filepath = name
	return true
end

return {
	BufferEntryValidator = BufferEntryValidator,
	is_ignored_buffer = is_ignored_buffer,
	is_in_diffview_tab = is_in_diffview_tab,
}
