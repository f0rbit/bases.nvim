-- Forked from miller3616/bases.nvim (GPL-3.0)
-- Original: lua/bases/engine/file_watcher.lua
-- Modified: uses vim.uv for filesystem events (Neovim-only module)

---@class FileWatcher
---@field handle userdata|nil The uv_fs_event handle
---@field timer userdata|nil The debounce timer handle
---@field pending table<string, boolean> Set of vault-relative paths pending notification
---@field vault_path string Absolute vault path
---@field on_change fun(event_type: string, path: string) Callback function
---@field stopped boolean Whether watcher has been stopped

local M = {}

local DEBOUNCE_MS = 300

---Check if a path is a hidden directory component
---@param path string
---@return boolean
local function has_hidden_dir(path)
	for part in vim.gsplit(path, "/", { plain = true }) do
		if vim.startswith(part, ".") and part ~= "." and part ~= ".." then
			return true
		end
	end
	return false
end

---Check if a file should be watched based on extension
---@param path string
---@return boolean
local function should_watch_file(path)
	return vim.endswith(path, ".md") or vim.endswith(path, ".base")
end

---Convert absolute path to vault-relative path
---@param vault_path string
---@param abs_path string
---@return string|nil
local function to_relative_path(vault_path, abs_path)
	if not abs_path then
		return nil
	end

	-- Normalize paths
	local normalized_vault = vim.fs.normalize(vault_path)
	local normalized_abs = vim.fs.normalize(abs_path)

	-- Check if abs_path starts with vault_path
	if vim.startswith(normalized_abs, normalized_vault) then
		local relative = normalized_abs:sub(#normalized_vault + 1)
		-- Remove leading slash
		if vim.startswith(relative, "/") then
			relative = relative:sub(2)
		end
		return relative
	end

	return nil
end

---Determine event type for a path
---@param vault_path string
---@param rel_path string
---@param is_rename boolean
---@return string|nil event_type "create" | "modify" | "delete" | nil
local function determine_event_type(vault_path, rel_path, is_rename)
	local abs_path = vim.fs.normalize(vault_path .. "/" .. rel_path)
	local stat = vim.uv.fs_stat(abs_path)

	if stat then
		-- File exists
		if is_rename then
			return "create"
		else
			return "modify"
		end
	else
		-- File doesn't exist
		return "delete"
	end
end

---Process pending changes and call on_change callback
---@param watcher FileWatcher
local function process_pending(watcher)
	if watcher.stopped then
		return
	end

	local pending_copy = {}
	for path, is_rename in pairs(watcher.pending) do
		table.insert(pending_copy, { path = path, is_rename = is_rename })
	end
	watcher.pending = {}

	for _, item in ipairs(pending_copy) do
		local event_type = determine_event_type(watcher.vault_path, item.path, item.is_rename)
		if event_type then
			local ok, err = pcall(watcher.on_change, event_type, item.path)
			if not ok then
				vim.schedule(function()
					vim.notify(
						string.format("File watcher callback error: %s", err),
						vim.log.levels.WARN
					)
				end)
			end
		end
	end
end

---Handle filesystem event
---@param watcher FileWatcher
---@param err string|nil
---@param filename string|nil
---@param events table|nil
local function on_fs_event(watcher, err, filename, events)
	if watcher.stopped then
		return
	end

	vim.schedule(function()
		if err then
			vim.notify(
				string.format("File watcher error: %s", err),
				vim.log.levels.WARN
			)
			return
		end

		if not filename then
			return
		end

		-- Build absolute path
		local abs_path = vim.fs.normalize(watcher.vault_path .. "/" .. filename)

		-- Convert to relative path
		local rel_path = to_relative_path(watcher.vault_path, abs_path)
		if not rel_path then
			return
		end

		-- Filter hidden directories
		if has_hidden_dir(rel_path) then
			return
		end

		-- Filter by file extension
		if not should_watch_file(rel_path) then
			return
		end

		-- Determine if this is a rename event
		local is_rename = events and events.rename or false

		-- Add to pending set
		watcher.pending[rel_path] = is_rename

		-- Reset debounce timer
		if watcher.timer then
			watcher.timer:stop()
			watcher.timer:start(DEBOUNCE_MS, 0, function()
				vim.schedule(function()
					process_pending(watcher)
				end)
			end)
		end
	end)
end

---Start watching a vault for file changes
---@param vault_path string Absolute path to the vault
---@param on_change fun(event_type: string, path: string) Callback for file changes
---@return FileWatcher|nil watcher The file watcher instance, or nil on error
---@return string|nil error Error message if failed
function M.start(vault_path, on_change)
	if type(vault_path) ~= "string" or vault_path == "" then
		return nil, "vault_path must be a non-empty string"
	end

	if type(on_change) ~= "function" then
		return nil, "on_change must be a function"
	end

	-- Normalize vault path
	vault_path = vim.fs.normalize(vault_path)

	-- Check if vault path exists
	local stat = vim.uv.fs_stat(vault_path)
	if not stat or stat.type ~= "directory" then
		return nil, string.format("vault_path is not a valid directory: %s", vault_path)
	end

	---@type FileWatcher
	local watcher = {
		handle = nil,
		timer = nil,
		pending = {},
		vault_path = vault_path,
		on_change = on_change,
		stopped = false,
	}

	-- Create debounce timer
	local timer = vim.uv.new_timer()
	if not timer then
		return nil, "Failed to create debounce timer"
	end
	watcher.timer = timer

	-- Create fs_event handle
	local handle = vim.uv.new_fs_event()
	if not handle then
		timer:close()
		return nil, "Failed to create fs_event handle"
	end
	watcher.handle = handle

	-- Start watching
	local ok, start_err = pcall(function()
		handle:start(vault_path, { recursive = true }, function(err, filename, events)
			on_fs_event(watcher, err, filename, events)
		end)
	end)

	if not ok then
		timer:close()
		handle:close()
		return nil, string.format("Failed to start watching: %s", start_err)
	end

	return watcher
end

---Stop the file watcher
---@param self FileWatcher
function M.stop(self)
	if self.stopped then
		return
	end

	self.stopped = true

	-- Stop and close timer
	if self.timer then
		if not self.timer:is_closing() then
			self.timer:stop()
			self.timer:close()
		end
		self.timer = nil
	end

	-- Stop and close fs_event handle
	if self.handle then
		if not self.handle:is_closing() then
			self.handle:stop()
			self.handle:close()
		end
		self.handle = nil
	end

	-- Clear pending changes
	self.pending = {}
end

---Create metatable for FileWatcher
local FileWatcher = {}
FileWatcher.__index = FileWatcher
FileWatcher.stop = M.stop

---Override start to return instance with metatable
local original_start = M.start
function M.start(vault_path, on_change)
	local watcher, err = original_start(vault_path, on_change)
	if not watcher then
		return nil, err
	end
	return setmetatable(watcher, FileWatcher)
end

return M
