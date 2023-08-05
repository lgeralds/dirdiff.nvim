local api = vim.api
local M = {
  tab_buf = {}
}

function M:close_cur_tab()
  local cur_tab = api.nvim_get_current_tabpage()
  local bufs = self.tab_buf[cur_tab] or {}
  self.tab_buf[cur_tab] = {}

  for _, buf in ipairs(bufs) do
    -- api.nvim_command("bd " .. buf)
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_delete(buf, {})
    end
  end
end

function M:close_all_tab()
  for i, bufs in pairs(self.tab_buf) do
    self.tab_buf[i] = {}
    for _, buf in ipairs(bufs) do
      if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_delete(buf, {})
      end
    end
  end
end

function M:create_diff_view(mine, other)
  api.nvim_command("tabnew")
  -- local cur_tab = api.nvim_get_current_tabpage()

  api.nvim_command("vs")

  -- api.nvim_command("wincmd h")
  -- api.nvim_command("e " .. other)
  -- api.nvim_command("diffthis")
  -- local buf1 = api.nvim_get_current_buf()
  -- local win1 = api.nvim_get_current_win()
  -- api.nvim_win_set_option(win1, "signcolumn", "no")

  -- api.nvim_command("wincmd l")
  -- api.nvim_command("e " .. mine)
  -- api.nvim_command("diffthis")
  -- local buf2 = api.nvim_get_current_buf()
  -- local win2 = api.nvim_get_current_win()
  -- api.nvim_win_set_option(win2, "signcolumn", "no")
  -- self.tab_buf[cur_tab] = { buf1, buf2 }

  self.tab_buf[api.nvim_get_current_tabpage()] = {
    self:create_buf_view(other, 'h'),
    self:create_buf_view(mine, 'l')
  }
  -- hide diagnostic text
  -- print('HIDING')
  vim.diagnostic.config({ virtual_text = false, virtual_lines = false })
end

function M:create_buf_view(content, placement)
  api.nvim_command('wincmd ' .. placement)
  api.nvim_command('edit ' .. content)
  api.nvim_command('diffthis')
  api.nvim_win_set_option(
    api.nvim_get_current_win(),
    'signcolumn',
    'no'
  )

  return api.nvim_get_current_buf()
end

return M
