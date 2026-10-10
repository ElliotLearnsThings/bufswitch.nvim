---@class BufferHistoryUtils
local BufferHistoryUtils = {}

local buffer_entry = require("bufswitch.buffer_entries")

---@param self BufferHistory
---@param is_pinned? boolean
---@param filepath? string
---@param bufnr? integer
---@return BufferEntry? new_entry Not validated yet, use new_entry.validator.validate
function BufferHistoryUtils:new_entry(is_pinned, filepath, bufnr)
	return buffer_entry.new({
		is_pinned = is_pinned,
		filepath = filepath,
		bufnr = bufnr,
	})
end

---Finds the entries matching any of filepath, bufnr or index
---@param self BufferHistory
---@param filepath? string
---@param bufnr? integer
---@param index? integer
---@param exclude_pinned? boolean never match pinned entries
---@return integer[]? idxs ascending indices of the matches, nil if none
function BufferHistoryUtils:get_matching_entry_idx(filepath, bufnr, index, exclude_pinned)
	local inds = {}

	for idx, entry in ipairs(self.history) do
		local skip = exclude_pinned and entry.is_pinned
		local matches = idx == index
			or (filepath ~= nil and entry.filepath == filepath)
			or (bufnr ~= nil and entry.bufnr == bufnr)
		if matches and not skip then
			table.insert(inds, idx)
		end
	end

	return #inds > 0 and inds or nil
end

---@param self BufferHistory
---@param entry BufferEntry
---@return nil
function BufferHistoryUtils:append(entry)
	self.utils.remove(self, entry.filepath, entry.bufnr) -- no duplicates
	table.insert(self.history, entry)
	self.current_index = #self.history
end

---Removes the entries matching any of filepath, bufnr or index
---@param self BufferHistory
---@param filepath? string
---@param bufnr? integer
---@param index? integer
---@param exclude_pinned? boolean keep pinned entries
function BufferHistoryUtils:remove(filepath, bufnr, index, exclude_pinned)
	local inds = self.utils.get_matching_entry_idx(self, filepath, bufnr, index, exclude_pinned)

	if not inds then
		return
	end

	-- Remove from the back so each removal leaves the remaining indices in place
	for k = #inds, 1, -1 do
		table.remove(self.history, inds[k])
		if inds[k] < self.current_index then
			self.current_index = self.current_index - 1
		end
	end
	self.current_index = math.min(self.current_index, #self.history)
end

---Removes the entry shown as `number` in the bar (1 = most recent), staying on the current buffer
---@param self BufferHistory
---@param number integer
---@return nil
function BufferHistoryUtils:delete_at_target(number)
	if #self.history == 0 then
		vim.notify("No buffers left in history")
		return
	end

	local target = #self.history - number + 1
	if target < 1 or target > #self.history or #self.history <= 1 or target == self.current_index then
		return
	end

	table.remove(self.history, target)

	-- The current entry only shifts down when an older one went
	if target < self.current_index then
		self.current_index = self.current_index - 1
	end
end

---Removes the current entry and opens its older (or newer) neighbour
---@param self BufferHistory
---@param toward_newer boolean
---@return nil
function BufferHistoryUtils:remove_current(toward_newer)
	if #self.history <= 1 then
		return
	end

	local removed = self.current_index
	table.remove(self.history, removed)

	-- The newer neighbour slides into the removed slot, the older one sits just before it
	local target = toward_newer and removed or removed - 1
	self.current_index = math.max(1, math.min(target, #self.history))
	self.mover.open(self, self.current_index)
end

---@param self BufferHistory
---@return nil
function BufferHistoryUtils:clear()
	self.history = {}
	self.current_index = 0
	self.on_attach.on_attach(self) -- start again from the current buffer
	vim.notify("Cleared buffer history")
end

---@param self BufferHistory
---@return nil
function BufferHistoryUtils:toggle_pause()
	if not self.paused and #self.history == 0 then
		vim.notify("Warn: your buffer history is empty")
	end

	self.paused = not self.paused
	if self.paused then
		vim.print("Paused buffer addition")
	else
		vim.print("Unpaused buffer addition")
	end
end

return BufferHistoryUtils
