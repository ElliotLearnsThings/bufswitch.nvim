local validators = require("bufswitch.validation")

---@class BufferEntry
---@field filepath string
---@field is_pinned boolean
---@field bufnr integer
---@field validator BufferEntryValidator
local M = {}

---@param bufnr integer
---@return string? filepath nil for unnamed buffers
function M.get_filepath(bufnr)
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	return filepath ~= "" and filepath or nil
end

---@class NewEntryOpts
---@field filepath? string defaults to the buffer's name
---@field is_pinned? boolean
---@field bufnr? integer defaults to the current buffer

---@param opts NewEntryOpts
---@return BufferEntry? entry nil for unnamed buffers
---Not validated yet, use entry.validator.validate(entry, history)
function M.new(opts)
	local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
	local filepath = opts.filepath or M.get_filepath(bufnr)

	if filepath == nil then
		return nil
	end

	return setmetatable({
		filepath = filepath,
		is_pinned = opts.is_pinned or false,
		bufnr = bufnr,
		validator = validators.BufferEntryValidator,
	}, {__index = M})
end

return M
