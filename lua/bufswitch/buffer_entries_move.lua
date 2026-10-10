---@class BufferHistoryMover
local Mover = {}

---Opens the entry at `index`, dropping it instead if it no longer validates (e.g. wiped)
---@param self BufferHistory
---@param index integer index into self.history
---@return boolean success |TRUE| if success
function Mover:open(index)
	local entry = self.history[index]

	if self.debug then vim.notify(vim.inspect(entry)) end

	if not entry.validator.validate(entry, self) then
		vim.print("invalid file")
		self.utils.remove(self, entry.filepath)
		return false
	end

	self.current_index = index
	self.is_outside = false

	-- Already showing it: no BufEnter will come to clear is_viewing
	if entry.bufnr == vim.api.nvim_get_current_buf() then
		return true
	end

	self.is_viewing = true -- the BufEnter this causes is our own move, not a new visit
	local ok, err = pcall(vim.cmd.buffer, entry.bufnr)
	if not ok then
		self.is_viewing = false
		vim.notify(tostring(err), vim.log.levels.ERROR)
		return false
	end
	return true
end

---Goes to the entry shown as `number` in the bar, e.g. go to 1 -> most recent buffer
---@param self BufferHistory
---@param number integer
---@return boolean success |TRUE| if success
function Mover:go_to_number(number)
	if number < 1 or number > #self.history then
		vim.print("Does not exist!")
		return false
	end

	return self.mover.open(self, #self.history - number + 1)
end

---@param self BufferHistory
---@param amount integer
---@return boolean success |TRUE| if success
function Mover:go_back(amount)
	if #self.history == 0 then
		vim.print("Buffer history is empty!")
		return false
	end

	-- From a buffer outside the history, the first step back returns to the current entry
	local index = self.current_index - amount + (self.is_outside and 1 or 0)
	if index >= 1 then
		return self.mover.open(self, index)
	end

	-- Wrap around from the oldest to the most recent buffer
	if self.current_index == 1 then
		return self.mover.go_to_number(self, 1)
	end

	vim.print("Cannot move " .. amount .. " steps back!")
	return false
end

---@param self BufferHistory
---@param amount integer
---@return boolean success |TRUE| if success
function Mover:go_forward(amount)
	if #self.history == 0 then
		vim.print("Buffer history is empty!")
		return false
	end

	-- On the most recent entry this only returns to it from outside the history
	if self.current_index == #self.history then
		return self.mover.go_to_number(self, 1)
	end

	local index = self.current_index + amount
	if index > #self.history then
		return false
	end

	return self.mover.open(self, index)
end

return Mover
