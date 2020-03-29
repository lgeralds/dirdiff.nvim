local api = vim.api
local float_win = require('dirdiff/float_win')
local dir_diff = require('dirdiff/diff')
local log = require('dirdiff/log')

local path_sep = "/"

local M = {
	float_buf_id = 0,
	select_offset = 0,
	tab_buf = {},
	showed_diff = "",
	diff_info = {},
}

function M:close_cur_tab()
	local cur_tab = api.nvim_get_current_tabpage()
	local bufs = self.tab_buf[cur_tab] or {}
	self.tab_buf[cur_tab] = {}

	for _, buf in ipairs(bufs) do
		api.nvim_command("bd " .. buf)
	end
end

function M:close_all_tab()
	for i, bufs in pairs(self.tab_buf) do
		self.tab_buf[i] = {}
		for _, buf in ipairs(bufs) do
			api.nvim_command("bd " .. buf)
		end
	end
end

function M:create_diff_view(fname)
	local file1 = self.diff_info.others_root .. path_sep .. fname
	local file2 = self.diff_info.mine_root .. path_sep .. fname

	local ft1 = vim.fn.getftype(file1)
	local ft2 = vim.fn.getftype(file2)
	if ft1 == "dir" and ft1 == ft2 then
		self:diff_sub_dir(fname)
		return
	end

	api.nvim_command("tabnew")
	local cur_tab = api.nvim_get_current_tabpage()

	api.nvim_command("vs")

	api.nvim_command("wincmd h")
	api.nvim_command("e " .. file1)
	api.nvim_command("diffthis")
	local buf1 = api.nvim_get_current_buf()
	local win1 = api.nvim_get_current_win()
	api.nvim_win_set_option(win1, "signcolumn", "no")

	api.nvim_command("wincmd l")
	api.nvim_command("e " .. file2)
	api.nvim_command("diffthis")
	local buf2 = api.nvim_get_current_buf()
	local win2 = api.nvim_get_current_win()
	api.nvim_win_set_option(win2, "signcolumn", "no")
	self.tab_buf[cur_tab] = {buf1, buf2}
	-- call nvim_command("wincmd h")
end

function M:get_fname()
	local diff = self.diff_info.diff
	if self.showed_diff ~= "" then
		diff = self.diff_info.sub[self.showed_diff]
	end
	local cur_line = self.select_offset
	if cur_line <= #diff.change then
		log.debug("diff change")
		return diff.change[cur_line]
	end
	if cur_line <= #diff.change + #diff.add then
		log.debug("diff add")
		return diff.add[cur_line - #diff.change]
	end
	log.debug("diff delete")
	return diff.delete[cur_line - #diff.change - #diff.add]
end

function M:diff_cur_line()
	-- 1-based line num
	local cur_line = api.nvim_win_get_cursor(0)[1]
	log.debug(cur_line)
	self.select_offset = cur_line
	self:create_diff_view(self:get_fname())
end

function M:diff_next_line()
	self.select_offset = self.select_offset + 1
	local diff = self.diff_info.diff
	if self.showed_diff ~= "" then
		diff = self.diff_info.sub[self.showed_diff]
	end
	if self.select_offset > #diff.change + #diff.add + #diff.delete then
		self.select_offset = 1
	end
	self:create_diff_view(self:get_fname())
end

function M:diff_pre_line()
	self.select_offset = self.select_offset - 1
	local diff = self.diff_info.diff
	if self.showed_diff ~= "" then
		diff = self.diff_info.sub[self.showed_diff]
	end
	if self.select_offset < 1 then
		self.select_offset = #diff.change + #diff.add + #diff.delete
	end
	self:create_diff_view(self:get_fname())
end

function M:init_float_buf()
	if self.float_buf_id == 0 then
		self.float_buf_id = api.nvim_create_buf(false, true)
		api.nvim_buf_set_keymap(self.float_buf_id, 'n', '<cr>', 
			":lua require('dirdiff').diff_cur()<cr>", {silent = true})
		api.nvim_buf_set_keymap(self.float_buf_id, 'n', '<esc>', 
			":lua require('dirdiff').close_win()<cr>", {silent = true})
	else
		api.nvim_buf_clear_namespace(self.float_buf_id, -1, 0, -1)
		api.nvim_buf_set_lines(self.float_buf_id, 0, -1, false, {})
	end

end

function M:set_float_buf()
	self:init_float_buf()
	local buf_lines = {}
	local diff = self.diff_info.diff
	if self.showed_diff ~= "" then
		diff = self.diff_info.sub[self.showed_diff]
	end
	self:add_lines(buf_lines, diff.change, "~")
	self:add_lines(buf_lines, diff.add, "+")
	self:add_lines(buf_lines, diff.delete, "-")
	api.nvim_buf_set_lines(self.float_buf_id, 0, -1, false, buf_lines)
	self:buf_set_hls(0, #diff.change, "DirDiffChange")
	self:buf_set_hls(#diff.change, #diff.change + #diff.add, "DirDiffAdd")
	self:buf_set_hls(#diff.change + #diff.add, #buf_lines, "DirDiffRemove")
end

-- [start, tail)
function M:buf_set_hls(start, tail, hi)
	for line = start, tail-1 do
		api.nvim_buf_add_highlight(self.float_buf_id, 0, hi, line, 0, -1)
	end
end

function M:add_lines(dst, src, sign)
	for _, line in ipairs(src) do
		table.insert(dst, sign .. "\t" .. line)
	end
end

-- param {mine_root = "", others_root = "", diff = {}, sub = { f1 = {}, f2 = {}, f1/f3 = {} }}
function M:update(diff)
	self.diff_info = diff
	self.float_buf_id = 0
	self.select_offset = 0
	self.showed_diff = ""
	self:set_float_buf()
end

function M:diff_dir(mine, others)
end

function M:diff_sub_dir(fname)
	local mine_dir = self.diff_info.others_root .. path_sep .. fname
	local others_dir = self.diff_info.mine_root .. path_sep .. fname
	local diff_info = dir_diff.dir_diff(mine_dir, others_dir, is_rec)
	self.sub = self.sub or {}
	self.sub[fname] = diff_info.diff
	self.showed_diff = fname
	self.select_offset = 0
	self:set_float_buf()
end

return {
	update = function(diff) M:update(diff) end,
	show = function() float_win:create_float_win(M.float_buf_id) end,
	close_win = function() float_win:close_float_win() end,
	close_diff = function() M:close_cur_tab() end,
	close_diff_all = function() M:close_all_tab() end,
	diff_cur = function()
		M:diff_cur_line()
		float_win:close_float_win()
	end,
	diff_next = function() M:diff_next_line() end,
	diff_pre = function() M:diff_pre_line() end
}

