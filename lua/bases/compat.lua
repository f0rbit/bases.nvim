-- Forked from miller3616/bases.nvim (GPL-3.0)
-- Pure-Lua replacements for vim.* utilities so engine files
-- can be tested outside Neovim.
local M = {}

function M.startswith(s, prefix)
  return s:sub(1, #prefix) == prefix
end

function M.endswith(s, suffix)
  return suffix == "" or s:sub(-#suffix) == suffix
end

function M.trim(s)
  return s:match("^%s*(.-)%s*$")
end

function M.pesc(s)
  return s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

function M.tbl_isempty(t)
  return next(t) == nil
end

function M.tbl_keys(t)
  local keys = {}
  for k, _ in pairs(t) do keys[#keys + 1] = k end
  return keys
end

function M.tbl_count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function M.deepcopy(orig)
  if type(orig) ~= "table" then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[M.deepcopy(k)] = M.deepcopy(v)
  end
  return setmetatable(copy, getmetatable(orig))
end

function M.readfile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local lines = {}
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()
  return lines
end

function M.writefile(lines, path)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()
  return true
end

return M
