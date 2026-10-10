-- The scripted demo behind demo/demo.gif. From the repo root, watch it live with
--   nvim --clean -u demo/init.lua lua/bufswitch/init.lua
-- or record the GIF again with `vhs demo/demo.tape`.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

-- File icons and a colorscheme, cloned into the cache on the first run
local deps = vim.fn.stdpath("cache") .. "/bufswitch-demo"
for _, repo in ipairs({ "nvim-mini/mini.icons", "ellisonleao/gruvbox.nvim" }) do
	local path = deps .. "/" .. repo:match("[^/]+$")
	if not vim.uv.fs_stat(path) then
		vim.fn.system({ "git", "clone", "--depth=1", "https://github.com/" .. repo, path })
	end
	vim.opt.runtimepath:prepend(path)
end
vim.opt.runtimepath:prepend(root)

vim.g.mapleader = " "
vim.o.termguicolors = true
vim.o.number = true
vim.o.laststatus = 3
vim.o.swapfile = false
vim.cmd.colorscheme("gruvbox")

require("mini.icons").setup()
require("bufswitch").setup()

------ CAPTION CARD --------

-- A card in the top right corner saying what the current scene shows and which key was
-- just pressed, since a recording can't show <A-…> keys being typed

local ns = vim.api.nvim_create_namespace("bufswitch_demo")
local card = { buf = vim.api.nvim_create_buf(false, true), title = "", sub = "" }

vim.api.nvim_set_hl(0, "DemoTitle", { fg = "#fabd2f", bold = true })
vim.api.nvim_set_hl(0, "DemoSub", { fg = "#a89984" })
vim.api.nvim_set_hl(0, "DemoKey", { fg = "#282828", bg = "#8ec07c", bold = true })
vim.api.nvim_set_hl(0, "DemoAction", { fg = "#ebdbb2" })

---@param key? string the keys just pressed, as the README writes them
---@param action? string what they did
local function draw(key, action)
	local pill = key and " " .. key .. " " or ""
	local lines = { " " .. card.title, " " .. card.sub, "", key and "  " .. pill .. "  " .. action or "" }

	vim.api.nvim_buf_set_lines(card.buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(card.buf, ns, 0, -1)
	local function hl(row, start_col, end_col, group)
		vim.api.nvim_buf_set_extmark(card.buf, ns, row, start_col, { end_col = end_col, hl_group = group })
	end
	hl(0, 0, #lines[1], "DemoTitle")
	hl(1, 0, #lines[2], "DemoSub")
	if key then
		hl(3, 2, 2 + #pill, "DemoKey")
		hl(3, 2 + #pill, #lines[4], "DemoAction")
	end

	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
	end

	local win_config = {
		relative = "editor",
		anchor = "NE",
		row = 1,
		col = vim.o.columns - 1,
		width = width,
		height = #lines,
		style = "minimal",
		border = "rounded",
		title = " bufswitch.nvim ",
		focusable = false,
	}
	if card.win and vim.api.nvim_win_is_valid(card.win) then
		vim.api.nvim_win_set_config(card.win, win_config)
	else
		card.win = vim.api.nvim_open_win(card.buf, false, win_config)
	end
end

------ SCRIPT STEPS --------

-- The script runs in a coroutine, so each step can wait without blocking Neovim

---@param ms integer
local function sleep(ms)
	local co = coroutine.running()
	vim.defer_fn(function()
		local ok, err = coroutine.resume(co)
		if not ok then vim.notify(err, vim.log.levels.ERROR) end
	end, ms)
	coroutine.yield()
end

---Starts a scene
---@param title string
---@param sub string
---@param wait integer reading time before the first step
local function say(title, sub, wait)
	card.title, card.sub = title, sub
	draw()
	vim.cmd.echo('""') -- the last scene's messages
	sleep(wait)
end

---Presses keys through the user's mappings, like typing them
---@param keys string
---@param action string
local function press(keys, action)
	draw(keys, action)
	vim.cmd.echo('""') -- leaves room for the message these keys print
	vim.api.nvim_feedkeys(vim.keycode(keys), "m", false)
	sleep(1100)
end

---Types an Ex command into the command line one character at a time
---@param cmd string
---@param result string what it did to the bar
local function ex(cmd, result)
	draw()
	vim.api.nvim_feedkeys(":", "n", false)
	sleep(150)
	for char in cmd:gmatch(".") do
		vim.api.nvim_feedkeys(char, "n", false)
		sleep(30)
	end
	sleep(300)
	vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
	draw(":" .. cmd, result)
	sleep(1100)
end

------ THE DEMO --------

local function demo()
	say("Every file you open joins the bar, newest first", "No marking: :e, a picker or gd all count", 3500)
	ex("e README.md", "joins as 1")
	ex("e lua/bufswitch/ui.lua", "joins as 1")
	ex("e lua/bufswitch/config.lua", "joins as 1")

	say("Hotswitch to any entry with one home-row key", "Revisits never reorder it, so numbers stay put", 1800)
	press("<A-f>", "go to 4")
	press("<A-s>", "go to 2")
	press("<A-d>", "go to 3")
	press("<A-a>", "go to 1")

	say("Step back and forth through the list", "Both take a count, and back wraps around", 1600)
	press("<>", "back")
	press("<>", "back")
	press("><", "forward")
	press("2<>", "back 2")
	press("<>", "back, wrapping to 1")

	say("Drop the files you're done with", "The buffer stays open, only the entry goes", 1600)
	press("<leader>j3", "remove 3")
	press("<<", "remove this one, open the older")

	say("Pause to freeze a fixed working set, like harpoon", "New files stay off the bar until you add them", 1800)
	press("<leader>jl", "pause")
	ex("e LICENSE", "stays off the bar")
	press("<leader>jj", "add this buffer")
	press("<leader>jl", "resume")

	say("Past 7 entries the rest shrink to number and icon", "So the bar stays on one line", 1400)
	for _, name in ipairs({ "validation", "on_attach", "buffer_entries", "buffer_history_utils", "buffer_entries_move" }) do
		vim.cmd.edit("lua/bufswitch/" .. name .. ".lua")
		sleep(350)
	end
	sleep(800)
	press("<A-h>", "go to 6")
	press("<A-a>", "go to 1")

	-- demo.tape waits for this caption before it stops recording
	say("Every key is yours to change", 'keys = { jump = { "<leader>1", "<leader>2", ... } }', 4000)
end

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		coroutine.wrap(demo)()
	end,
})
