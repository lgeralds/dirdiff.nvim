local path_sep = "/"

if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
  path_sep = "\\"
end

local M = {}

function M.path_concat(left, right)
  local l = left
  local r = right
  if left[#left] == path_sep then
    l = left:sub(1, #left - 1)
  end
  if right[#right] == path_sep then
    r = right:sub(2)
  end

  return l .. path_sep .. r
end

function M.path_parent(path)
  if not path or #path == "" then
    return
  end

  local temp = vim.split(path, path_sep, { trimempty = true })
  if #temp == 1 then
    return ""
  end
  local parent = table.concat(temp, path_sep, 1, #temp - 1)
  return parent
end

M.parse_arg = function(...)
  local others = select(1, ...)
  if not others then
    return { ret = false }
  end
  local mine = select(2, ...)
  if not mine then
    mine = "."
  end
  others = vim.fn.glob(others)
  mine = vim.fn.glob(mine)
  return { ret = true, mine = mine, others = others }
end

M.cmdcomplete = function(A, _L, _P)
  local cwd = vim.fn.getcwd()
  if #A == 0 then
    return { cwd }
  end
  if cwd == A then
    return
  end
  local paths = vim.fn.glob(A .. "*", false, true)
  if #paths == 0 then
    return
  end
  -- paths = vim.split(paths, "\n")
  local ret = {}
  local pathc = ''
  for _, path in ipairs(paths) do
    pathc = string.gsub(path, " ", "\\ ")
    if vim.fn.getftype(path) == "dir" then
      table.insert(ret, pathc)
    end
  end
  return ret
end

M.fetchNodeName = function(file_src, cmdLine)
  local file_out = ''
  -- Read in the new file path using the existing file's path as the baseline.
  vim.ui.input(
    {
      prompt = cmdLine,
      completion = 'file',
      default = file_src
    },
    function(input)
      file_out = input
    end
  )

  return file_out
end

return M
