-- bases.nvim — Plugin entry point
-- Setup, config, commands, autocmds
local M = {}

M.config = {}
M.ns_id = vim.api.nvim_create_namespace("bases")

local defaults = {
  vault_path = nil,
  render = {
    max_col_width = 40,
    min_col_width = 5,
    max_table_width = nil,
    alternating_rows = true,
    border_style = "rounded",
    null_char = "\u{2014}",
    bool_true = "\u{2713}",
    bool_false = " ",
    list_separator = ", ",
  },
  inline = {
    enabled = true,
    auto_render = true,
  },
  watcher = {
    enabled = true,
    debounce_ms = 500,
  },
  index = {
    extensions = { "md" },
    ignore_dirs = { ".obsidian", ".git", ".trash", "node_modules" },
  },
}

--- Deep merge two tables (b overrides a)
local function deep_merge(a, b)
  local result = vim.deepcopy(a)
  for k, v in pairs(b or {}) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

--- Setup the plugin
---@param opts table? User config
function M.setup(opts)
  M.config = deep_merge(defaults, opts or {})

  if not M.config.vault_path then
    vim.notify("bases.nvim: vault_path is required in setup()", vim.log.levels.ERROR)
    return
  end

  -- Expand ~ in vault path
  M.config.vault_path = vim.fn.expand(M.config.vault_path)

  -- Setup engine — set vault path and start async initialization
  local engine = require("bases.engine")
  engine.init(M.config.vault_path, function(err)
    if err then
      vim.notify("bases.nvim: engine init failed: " .. err, vim.log.levels.ERROR)
    end
  end)

  -- Setup highlights
  local render = require("bases.render")
  render.setup_highlights()

  -- Register commands and autocmds
  M.register_commands()
  M.register_autocmds()
end

function M.register_commands()
  vim.api.nvim_create_user_command("BasesRender", function()
    M.render_current()
  end, { desc = "Render current .base file or inline blocks" })

  vim.api.nvim_create_user_command("BasesRefresh", function()
    require("bases.engine").rebuild_index(function(err)
      if err then
        vim.notify("bases.nvim: rebuild failed: " .. err, vim.log.levels.ERROR)
        return
      end
      M.render_current()
    end)
  end, { desc = "Re-index vault and re-render" })

  vim.api.nvim_create_user_command("BasesClear", function()
    M.clear_current()
  end, { desc = "Clear rendered output" })

  vim.api.nvim_create_user_command("BasesToggle", function()
    M.toggle_current()
  end, { desc = "Toggle rendered/raw view" })

  vim.api.nvim_create_user_command("BasesDebug", function()
    M.debug_current()
  end, { desc = "Show parsed base config" })
end

function M.register_autocmds()
  local group = vim.api.nvim_create_augroup("bases_nvim", { clear = true })

  -- .base files: render on open
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = "*.base",
    callback = function(ev)
      M.render_base_file(ev.buf, ev.file)
    end,
  })

  -- Markdown files: render inline blocks
  if M.config.inline.enabled and M.config.inline.auto_render then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      pattern = "*.md",
      callback = function(ev)
        local path = vim.api.nvim_buf_get_name(ev.buf)
        if path:find(M.config.vault_path, 1, true) then
          require("bases.inline").render(ev.buf)
        end
      end,
    })
  end

  -- Clean up inline generation tracking when buffers are wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(ev)
      require("bases.inline").on_buf_delete(ev.buf)
    end,
  })
end

--- Render a .base file into a scratch buffer
---@param bufnr integer
---@param filepath string
function M.render_base_file(bufnr, filepath)
  local buffer = require("bases.buffer")
  local engine = require("bases.engine")
  local render = require("bases.render")

  -- Setup the buffer as scratch
  buffer.create(filepath)
  buffer.set_keymaps(bufnr)
  buffer.set_lines(bufnr, { "Loading..." })

  engine.on_ready(function(init_err)
    if init_err then
      buffer.set_lines(bufnr, { "bases.nvim: " .. init_err })
      return
    end

    engine.query(filepath, 0, function(err, result)
      if err then
        buffer.set_lines(bufnr, { "bases.nvim: " .. err })
        return
      end
      if not result then
        buffer.set_lines(bufnr, { "bases.nvim: no result" })
        return
      end

      local lines, highlights = render.render(result, M.config.render)
      buffer.set_lines(bufnr, lines)
      buffer.apply_highlights(bufnr, highlights, M.ns_id)
    end)
  end)
end

--- Render current buffer (dispatch to .base or inline)
function M.render_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype

  if ft == "base" then
    local source = vim.b[bufnr].bases_source or vim.api.nvim_buf_get_name(bufnr)
    M.render_base_file(bufnr, source)
  elseif ft == "markdown" then
    require("bases.inline").render(bufnr)
  end
end

--- Clear current buffer rendering
function M.clear_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype

  if ft == "markdown" then
    require("bases.inline").clear(bufnr)
  end
end

--- Toggle rendered/raw view
function M.toggle_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype

  if ft == "markdown" then
    require("bases.inline").toggle(bufnr)
  end
end

--- Show debug info for current base
function M.debug_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype

  if ft == "base" then
    local source = vim.b[bufnr].bases_source or vim.api.nvim_buf_get_name(bufnr)
    local base_parser = require("bases.engine.base_parser")
    local config, err = base_parser.parse(source)
    if config then
      vim.notify(vim.inspect(config), vim.log.levels.INFO)
    else
      vim.notify("bases.nvim: parse error: " .. (err or "unknown"), vim.log.levels.ERROR)
    end
  end
end

--- Called by plugin/bases.lua on FileType=base
function M.attach()
  -- Per-buffer setup for .base files
  -- Currently handled by BufReadCmd, but this is the hook
  -- for future FileType-based setup
end

return M
