local buffer_entry = require("bufswitch.buffer_entries")

---@class BufferHistoryOnAttachHandler
local OnAttachHandler = {}

---Handles entering a buffer: moves the pointer to it if it is already in the history,
---otherwise appends it (unless paused, or the buffer is not allowed)
---@param self BufferHistory
---@param bypass? boolean record even while paused or right after our own move
---@return boolean is_success true if the buffer was appended
function OnAttachHandler:on_attach(bypass)
	local bufnr = vim.api.nvim_get_current_buf()
	local filepath = buffer_entry.get_filepath(bufnr)
	local matches = self.utils.get_matching_entry_idx(self, filepath, bufnr)

	if not bypass then
		if self.is_viewing then
			-- This BufEnter came from our own move, which already set the pointer
			if self.debug then vim.print("[on_attach] left due to viewing") end
			self.is_viewing = false
			return false
		end

		if self.paused then
			-- Not recording, but when we enter a buffer that is already in the history the
			-- pointer follows it, so moving around afterwards starts from the right place
			if self.debug then vim.print("[on_attach] left due to paused") end
			self.is_outside = matches == nil
			if matches then
				self.current_index = matches[#matches]
			end
			return false
		end
	end

	if matches then
		self.current_index = matches[#matches]
		self.is_outside = false
		return false
	end

	local new_entry = self.utils.new_entry(self, false, filepath, bufnr)
	if new_entry == nil or not new_entry.validator.validate(new_entry, self) then
		if self.debug then vim.print("[on_attach] not recording buffer " .. bufnr) end
		return false
	end

	self.utils.append(self, new_entry)
	self.is_outside = false
	return true
end

return OnAttachHandler
