local api = vim.api
local float_win = require('dirdiff.float_win')
local dir_diff = require('dirdiff.diff')
local diff_win = require('dirdiff.diff_win')
local plat = require('dirdiff.plat')

local M = {
  float_buf_id = 0,
  select_offset = 0,
  showed_diff = "",
  diff_info = {},
}

function M:create_diff_view(fname)
  local p = self:get_path(fname)
  if p.mine_ft == p.other_ft and p.mine_ft == "dir" then
    self:diff_sub_dir(fname)
    return
  end
  diff_win:create_diff_view(p.mine, p.other)
end

function M:get_fname()
  local diff = self.diff_info.diff
  if self.showed_diff ~= "" then
    diff = self.diff_info.sub[self.showed_diff]
  end
  local cur_line = self.select_offset - 1
  if cur_line <= #diff.change then
    return diff.change[cur_line]
  end
  if cur_line <= #diff.change + #diff.add then
    return diff.add[cur_line - #diff.change]
  end
  return diff.delete[cur_line - #diff.change - #diff.add]
end

function M:diff_cur_line()
  -- 1-based line num
  local cur_line = api.nvim_win_get_cursor(0)[1]
  self.select_offset = cur_line
  if self.select_offset == 1 then
    self:back_parent_dir()
    return
  end
  self:create_diff_view(self:get_fname())
end

function M:diff_next_line()
  local diff = self.diff_info.diff
  if self.showed_diff ~= "" then
    diff = self.diff_info.sub[self.showed_diff]
  end
  if self.select_offset > #diff.change + #diff.add + #diff.delete then
    self.select_offset = 2
  else
    self.select_offset = self.select_offset + 1
  end
  self:create_diff_view(self:get_fname())
end

function M:diff_pre_line()
  local diff = self.diff_info.diff
  if self.showed_diff ~= "" then
    diff = self.diff_info.sub[self.showed_diff]
  end
  self.select_offset = self.select_offset - 1
  if self.select_offset <= 1 then
    self.select_offset = #diff.change + #diff.add + #diff.delete + 1
  end
  self:create_diff_view(self:get_fname())
end

function M:back_parent_dir()
  if self.showed_diff == "" then
    return
  end

  local parent = plat.path_parent(self.showed_diff)
  self:update_to(parent)
end

function M:init_float_buf()
  if self.float_buf_id == 0 then
    self.float_buf_id = api.nvim_create_buf(false, true)
    api.nvim_buf_set_keymap(self.float_buf_id, 'n', '<cr>',
      ":lua require('dirdiff').diff_cur()<cr>", { silent = true })
    api.nvim_buf_set_keymap(self.float_buf_id, 'n', '<esc>',
      ":lua require('dirdiff').close_win()<cr>", { silent = true })
  else
    api.nvim_buf_clear_namespace(self.float_buf_id, -1, 0, -1)
    api.nvim_buf_set_lines(self.float_buf_id, 0, -1, false, {})
  end
end

function M:set_float_buf()
  self:init_float_buf()
  local buf_lines = { "../" }
  local diff = self.diff_info.diff
  if self.showed_diff ~= "" then
    diff = self.diff_info.sub[self.showed_diff]
  end
  self:add_lines(buf_lines, diff.change, "~")
  self:add_lines(buf_lines, diff.add, "+")
  self:add_lines(buf_lines, diff.delete, "-")
  api.nvim_buf_set_lines(self.float_buf_id, 0, -1, false, buf_lines)
  self:buf_set_hls(0, 1, "DirDiffBack")
  self:buf_set_hls(1, #diff.change + 1, "DirDiffChange")
  self:buf_set_hls(#diff.change + 1, #diff.change + #diff.add + 1, "DirDiffAdd")
  self:buf_set_hls(#diff.change + #diff.add + 1, #buf_lines, "DirDiffRemove")
end

-- [start, tail) zero-based
function M:buf_set_hls(start, tail, hi)
  for line = start, tail - 1 do
    api.nvim_buf_add_highlight(self.float_buf_id, 0, hi, line, 0, -1)
  end
end

function M:add_lines(dst, src, sign)
  for _, line in ipairs(src) do
    local p = self:get_path(line)
    local prefix = ""
    if p.mine_ft == "file" and p.other_ft == "file" then
      prefix = "f"
    elseif p.mine_ft == "dir" and p.other_ft == "dir" then
      prefix = "d"
    else
      prefix = "x"
    end
    table.insert(dst, prefix .. sign .. "\t\t" .. line)
  end
end

function M:get_path(fname)
  local real_fname = fname
  if self.showed_diff ~= "" then
    real_fname = plat.path_concat(self.showed_diff, fname)
  end
  local mine = plat.path_concat(self.diff_info.mine_root, real_fname)
  local other = plat.path_concat(self.diff_info.others_root, real_fname)
  local mine_ft = vim.fn.getftype(mine)
  local other_ft = vim.fn.getftype(other)
  if mine_ft == "" then
    mine_ft = other_ft
  end
  if other_ft == "" then
    other_ft = mine_ft
  end
  return { mine = mine, other = other, mine_ft = mine_ft, other_ft = other_ft }
end

function M:update_to(sub_dir)
  self.select_offset = 0
  self.showed_diff = sub_dir
  self:set_float_buf()
end

-- param {mine_root = "", others_root = "", diff = {}, sub = { f1 = {}, f2 = {}, f1/f3 = {} }}
function M:update(diff)
  self.diff_info = diff
  self.float_buf_id = 0
  self:update_to("")
end

function M:diff_dir(mine, others, is_rec)
  self:update(dir_diff.diff_dir(mine, others, is_rec))
  --float_win:create_float_win(self.float_buf_id)
  self:show()
end

function M:diff_sub_dir(fname)
  local sub_dir = fname
  if self.showed_diff ~= "" then
    sub_dir = plat.path_concat(self.showed_diff, fname)
  end
  if not self.diff_info.sub or not self.diff_info.sub[sub_dir] then
    local mine_dir = plat.path_concat(self.diff_info.mine_root, sub_dir)
    local others_dir = plat.path_concat(self.diff_info.others_root, sub_dir)
    local diff_info = dir_diff.diff_dir(mine_dir, others_dir, true)
    self.diff_info.sub = self.diff_info.sub or {}
    self.diff_info.sub[sub_dir] = diff_info.diff
  end
  self:update_to(sub_dir)
end

function M:show()
  float_win:create_float_win(M.float_buf_id)
  -- hide diagnostic test
  vim.diagnostic.config({ virtual_text = false, virtual_lines = true })
end

function M:close_win()
  float_win:close_float_win()
end

return M
