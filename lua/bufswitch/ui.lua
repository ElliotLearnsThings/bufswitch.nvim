-- The history bar in the winbar: most recent buffer first, each with its filetype icon.

local config = require("bufswitch.config")

---@class BufferHistoryUI
local UI = {}

-- Icon highlights: colour from the icon provider, background from the pill the icon
-- sits in. Made on demand and forgotten on colorscheme change.
local icon_hls = {}

---@return nil
function UI.set_highlights()
	-- Follow the colorscheme's tabline, unless the user set these groups themselves
	local base = vim.api.nvim_get_hl(0, { name = "TabLineSel", link = false })
	vim.api.nvim_set_hl(0, "BufSwitchSel", vim.tbl_extend("force", base, { bold = true, default = true }))
	vim.api.nvim_set_hl(0, "BufSwitchDim", { link = "TabLine", default = true })
	icon_hls = {}
end

---@param icon_hl string
---@param pill_hl string
---@return string hl_name
local function icon_highlight(icon_hl, pill_hl)
	local name = "BufSwitchIcon" .. icon_hl:gsub("[^%w]", "") .. pill_hl
	if not icon_hls[name] then
		local fg = vim.api.nvim_get_hl(0, { name = icon_hl, link = false }).fg
		local bg = vim.api.nvim_get_hl(0, { name = pill_hl, link = false }).bg
		vim.api.nvim_set_hl(0, name, { fg = fg, bg = bg })
		icon_hls[name] = true
	end
	return name
end

---@param filepath string
---@return string? icon
---@return string? hl
local function file_icon(filepath)
	if _G.MiniIcons then
		local icon, hl = _G.MiniIcons.get("file", filepath)
		return icon, hl
	end

	local ok, devicons = pcall(require, "nvim-web-devicons")
	if ok then
		local name = vim.fn.fnamemodify(filepath, ":t")
		return devicons.get_icon(name, vim.fn.fnamemodify(name, ":e"), { default = true })
	end
end

---The coloured icon, then back to the pill's highlight; "" without an icon provider
---@param filepath string
---@param pill_hl string
---@return string
local function icon_segment(filepath, pill_hl)
	local icon, hl = file_icon(filepath)
	if not icon then
		return ""
	end
	return "%#" .. icon_highlight(hl or pill_hl, pill_hl) .. "#" .. icon .. "%#" .. pill_hl .. "#"
end

---The bar as a statusline string, for the winbar or any other statusline-like option
---@param self BufferHistory
---@return string
function UI.render(self)
	local current_name = vim.api.nvim_buf_get_name(0)
	local count = #self.history
	local bar = ""

	-- Most recent first; the numbers are the ones the jump and remove keys use
	for idx = count, 1, -1 do
		local entry = self.history[idx]
		local number = count - idx + 1
		local filename = vim.fn.fnamemodify(entry.filepath, ":t"):gsub("%%", "%%%%")
		local selected = idx == self.current_index and entry.filepath == current_name
		local icon = icon_segment(entry.filepath, selected and "BufSwitchSel" or "BufSwitchDim")

		if selected then
			bar = bar .. "%#BufSwitchSel#  " .. number .. ": "
				.. (icon ~= "" and icon .. " " or "") .. filename .. "  %* "
		elseif count > config.options.compact_after then
			bar = bar .. " %#BufSwitchDim#[" .. number .. (icon ~= "" and " " .. icon or "") .. "]%* "
		else
			bar = bar .. " %#BufSwitchDim#" .. number .. ": "
				.. (icon ~= "" and icon .. " " or "") .. filename .. "%* "
		end
	end

	return bar
end

---@param self BufferHistory
---@return nil
function UI.update(self)
	if not config.options.winbar then
		-- The bar lives in the user's own tabline or statusline, which may not redraw on its own
		vim.cmd.redrawtabline()
		vim.cmd.redrawstatus()
		return
	end

	-- Global value only: windows that draw their own winbar (avante, diffview) keep it
	vim.go.winbar = UI.render(self)
end

return UI
