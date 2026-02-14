-- Forked from miller3616/bases.nvim (GPL-3.0)
-- Original: lua/bases/engine/note_index.lua
-- Modified: uses vim.uv for filesystem (Neovim-only module)

--- Vault index singleton that scans markdown files and builds an in-memory index
local M = {}

local yaml = require("bases.engine.yaml")

--- NoteData structure representing a single note
---@class NoteData
---@field path string Vault-relative path
---@field name string File name with extension
---@field basename string File name without extension
---@field folder string Parent folder path
---@field ext string File extension
---@field ctime number Creation time in milliseconds
---@field mtime number Modification time in milliseconds
---@field size number File size in bytes
---@field frontmatter table Parsed frontmatter data
---@field tags string[] Array of tags
---@field tag_set table<string, boolean> Set of tags for O(1) lookup (lowercase)
---@field links string[] Array of outgoing wikilinks
---@field outgoing_link_set table<string, boolean> Set of outgoing links for O(1) lookup

--- NoteIndex structure
---@class NoteIndex
---@field vault_path string Absolute path to vault root
---@field notes table<string, NoteData> Map of path to NoteData
---@field by_tag table<string, table<string, boolean>> Map of tag (lowercase) to set of paths
---@field by_folder table<string, table<string, boolean>> Map of folder to set of paths
---@field by_outgoing_link table<string, table<string, boolean>> Map of link target to set of source paths
local NoteIndex = {}
NoteIndex.__index = NoteIndex

--- Create a new NoteIndex
---@param vault_path string Absolute path to vault root
---@return NoteIndex
function M.new(vault_path)
  local self = setmetatable({}, NoteIndex)
  self.vault_path = vault_path
  self.notes = {}
  self.by_tag = {}
  self.by_folder = {}
  self.by_outgoing_link = {}
  return self
end

--- Check if a directory should be skipped
---@param name string Directory name
---@return boolean
local function should_skip_dir(name)
  if name:match("^%.") then
    return true
  end
  if name == ".obsidian" or name == ".git" or name == ".trash" then
    return true
  end
  return false
end

--- Expand hierarchical tags (e.g., "project/active" -> {"project/active", "project"})
---@param tag string Tag to expand
---@return string[] Expanded tags
local function expand_tag(tag)
  local result = { tag }
  local parts = {}

  for part in tag:gmatch("[^/]+") do
    table.insert(parts, part)
  end

  if #parts > 1 then
    for i = 1, #parts - 1 do
      local partial = table.concat(parts, "/", 1, i)
      table.insert(result, partial)
    end
  end

  return result
end

--- Extract frontmatter and body from file content
---@param content string File content
---@return table, string Frontmatter table and body string
local function extract_frontmatter(content)
  local lines = {}
  for line in content:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end

  if #lines == 0 or lines[1]:match("^%s*$") or lines[1] ~= "---" then
    return {}, content
  end

  -- Find closing delimiter
  local end_idx = nil
  for i = 2, #lines do
    if lines[i] == "---" or lines[i] == "..." then
      end_idx = i
      break
    end
  end

  if not end_idx then
    return {}, content
  end

  -- Extract frontmatter
  local fm_lines = {}
  for i = 2, end_idx - 1 do
    table.insert(fm_lines, lines[i])
  end

  local fm_text = table.concat(fm_lines, "\n")
  local frontmatter = yaml.parse(fm_text)

  -- Extract body
  local body_lines = {}
  for i = end_idx + 1, #lines do
    table.insert(body_lines, lines[i])
  end
  local body = table.concat(body_lines, "\n")

  return frontmatter, body
end

--- Extract wikilinks from markdown body
---@param body string Markdown body text
---@return string[] Array of link targets
local function extract_links(body)
  local links = {}
  local seen = {}

  for link in body:gmatch("%[%[([^%]|]+)") do
    local target = link:match("^([^|#]+)")
    if target and not seen[target] then
      table.insert(links, target)
      seen[target] = true
    end
  end

  return links
end

--- Read and parse a file
---@param file_path string Absolute path to file
---@return table|nil, string|nil Frontmatter and body, or nil on error
local function read_file(file_path)
  local fd = vim.uv.fs_open(file_path, "r", 438) -- 438 = 0666 in octal
  if not fd then
    return nil, nil
  end

  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil, nil
  end

  local content = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)

  if not content then
    return nil, nil
  end

  local frontmatter, body = extract_frontmatter(content)
  return frontmatter, body
end

--- Parse a file path into components
---@param vault_path string Vault root path
---@param abs_path string Absolute file path
---@return string, string, string, string, string Relative path, name, basename, folder, ext
local function parse_path_components(vault_path, abs_path)
  local rel_path = abs_path:sub(#vault_path + 2) -- +2 to skip trailing slash
  local name = rel_path:match("([^/]+)$")
  local folder = rel_path:match("^(.+)/[^/]+$") or ""
  local basename, ext = name:match("^(.+)%.([^%.]+)$")

  if not basename then
    basename = name
    ext = ""
  end

  return rel_path, name, basename, folder, ext
end

--- Create NoteData from file
---@param vault_path string Vault root path
---@param abs_path string Absolute file path
---@param stat table File stat info
---@return NoteData|nil
local function create_note_data(vault_path, abs_path, stat)
  local frontmatter, body = read_file(abs_path)
  if not frontmatter then
    return nil
  end

  local rel_path, name, basename, folder, ext = parse_path_components(vault_path, abs_path)

  -- Extract tags from frontmatter
  local tags = {}
  local tag_set = {}

  if frontmatter.tags then
    local fm_tags = frontmatter.tags
    if type(fm_tags) == "string" then
      fm_tags = { fm_tags }
    end

    for _, tag in ipairs(fm_tags) do
      local expanded = expand_tag(tag)
      for _, exp_tag in ipairs(expanded) do
        if not tag_set[exp_tag:lower()] then
          table.insert(tags, exp_tag)
          tag_set[exp_tag:lower()] = true
        end
      end
    end
  end

  -- Extract links
  local links = extract_links(body or "")
  local outgoing_link_set = {}
  for _, link in ipairs(links) do
    outgoing_link_set[link] = true
  end

  return {
    path = rel_path,
    name = name,
    basename = basename,
    folder = folder,
    ext = ext,
    ctime = stat.birthtime.sec * 1000,
    mtime = stat.mtime.sec * 1000,
    size = stat.size,
    frontmatter = frontmatter,
    tags = tags,
    tag_set = tag_set,
    links = links,
    outgoing_link_set = outgoing_link_set,
  }
end

--- Cache version; bump on schema changes
local CACHE_VERSION = 2

--- Get the cache file path for a vault
---@param vault_path string Absolute path to vault root
---@return string
local function get_cache_path(vault_path)
  return vault_path .. "/.obsidian/plugins/bases/note-cache.mpack"
end

--- Serialize a NoteData for msgpack storage (strips derived sets)
---@param note NoteData
---@return table
local function serialize_note(note)
  return {
    path = note.path,
    name = note.name,
    basename = note.basename,
    folder = note.folder,
    ext = note.ext,
    ctime = note.ctime,
    mtime = note.mtime,
    size = note.size,
    frontmatter = note.frontmatter,
    tags = note.tags,
    links = note.links,
  }
end

--- Deserialize a cached note entry, reconstructing derived sets
---@param data table
---@return NoteData
local function deserialize_note(data)
  local tag_set = {}
  if data.tags then
    for _, tag in ipairs(data.tags) do
      tag_set[tag:lower()] = true
    end
  end

  local outgoing_link_set = {}
  if data.links then
    for _, link in ipairs(data.links) do
      outgoing_link_set[link] = true
    end
  end

  data.tag_set = tag_set
  data.outgoing_link_set = outgoing_link_set
  return data
end

--- Load cached notes from disk
---@param cache_path string Path to cache msgpack file
---@param vault_path string Expected vault path for validation
---@return table<string, table> Map of path to serialized note data, or empty table
local function load_cache(cache_path, vault_path)
  local fd = vim.uv.fs_open(cache_path, "r", 438)
  if not fd then
    return {}
  end

  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return {}
  end

  local content = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)

  if not content or content == "" then
    return {}
  end

  local ok, cache = pcall(vim.mpack.decode, content)
  if not ok or type(cache) ~= "table" then
    return {}
  end

  if cache.version ~= CACHE_VERSION then
    return {}
  end

  if cache.vault_path ~= vault_path then
    return {}
  end

  if type(cache.notes) ~= "table" then
    return {}
  end

  return cache.notes
end

--- Save the note index cache to disk
---@param note_index_instance NoteIndex
local function save_cache(note_index_instance)
  local cache_path = get_cache_path(note_index_instance.vault_path)
  local dir = cache_path:match("^(.+)/[^/]+$")
  if dir then
    vim.fn.mkdir(dir, "p")
  end

  local notes = {}
  for path, note in pairs(note_index_instance.notes) do
    notes[path] = serialize_note(note)
  end

  local cache = {
    version = CACHE_VERSION,
    vault_path = note_index_instance.vault_path,
    notes = notes,
  }

  local ok, encoded = pcall(vim.mpack.encode, cache)
  if not ok then
    return
  end

  local fd = vim.uv.fs_open(cache_path, "w", 438)
  if not fd then
    return
  end

  vim.uv.fs_write(fd, encoded, 0)
  vim.uv.fs_close(fd)
end

--- Add a note to secondary indices
---@param self NoteIndex
---@param note NoteData
local function add_to_indices(self, note)
  -- Add to by_tag
  for tag_lower, _ in pairs(note.tag_set) do
    if not self.by_tag[tag_lower] then
      self.by_tag[tag_lower] = {}
    end
    self.by_tag[tag_lower][note.path] = true
  end

  -- Add to by_folder
  if not self.by_folder[note.folder] then
    self.by_folder[note.folder] = {}
  end
  self.by_folder[note.folder][note.path] = true

  -- Add to by_outgoing_link
  for link, _ in pairs(note.outgoing_link_set) do
    if not self.by_outgoing_link[link] then
      self.by_outgoing_link[link] = {}
    end
    self.by_outgoing_link[link][note.path] = true
  end
end

--- Remove a note from secondary indices
---@param self NoteIndex
---@param note NoteData
local function remove_from_indices(self, note)
  -- Remove from by_tag
  for tag_lower, _ in pairs(note.tag_set) do
    if self.by_tag[tag_lower] then
      self.by_tag[tag_lower][note.path] = nil
      if not next(self.by_tag[tag_lower]) then
        self.by_tag[tag_lower] = nil
      end
    end
  end

  -- Remove from by_folder
  if self.by_folder[note.folder] then
    self.by_folder[note.folder][note.path] = nil
    if not next(self.by_folder[note.folder]) then
      self.by_folder[note.folder] = nil
    end
  end

  -- Remove from by_outgoing_link
  for link, _ in pairs(note.outgoing_link_set) do
    if self.by_outgoing_link[link] then
      self.by_outgoing_link[link][note.path] = nil
      if not next(self.by_outgoing_link[link]) then
        self.by_outgoing_link[link] = nil
      end
    end
  end
end

--- Scan directories in batches to avoid blocking the UI.
--- Calls back with the list of collected .md file paths.
---@param root string Vault root directory
---@param callback fun(files: string[])
local function scan_directory_async(root, callback)
  local dirs_to_visit = { root }
  local files = {}
  local DIRS_PER_BATCH = 20

  local function scan_batch()
    local processed = 0
    while #dirs_to_visit > 0 and processed < DIRS_PER_BATCH do
      local dir_path = table.remove(dirs_to_visit)
      processed = processed + 1

      local handle = vim.uv.fs_scandir(dir_path)
      if handle then
        while true do
          local name, type = vim.uv.fs_scandir_next(handle)
          if not name then
            break
          end

          local full_path = dir_path .. "/" .. name

          if type == "directory" then
            if not should_skip_dir(name) then
              table.insert(dirs_to_visit, full_path)
            end
          elseif type == "file" then
            if name:match("%.md$") then
              table.insert(files, full_path)
            end
          end
        end
      end
    end

    if #dirs_to_visit > 0 then
      vim.schedule(scan_batch)
    else
      callback(files)
    end
  end

  scan_batch()
end

--- Save the note index cache to disk
function NoteIndex:save_cache()
  save_cache(self)
end

--- Build the full index asynchronously, using cache for unchanged files.
--- Directory scanning, file classification (stat), and note processing all
--- yield to the event loop periodically to avoid blocking the UI.
---@param self NoteIndex
---@param callback function Called when build is complete
function NoteIndex:build(callback)
  -- Load existing cache (single file read, fast — keep synchronous)
  local cache_path = get_cache_path(self.vault_path)
  local cached_notes = load_cache(cache_path, self.vault_path)

  -- Phase 1: scan directories (async, yields every 20 dirs)
  scan_directory_async(self.vault_path, function(files)

    -- Phase 2: classify files by stat-ing in batches
    local STAT_BATCH = 100
    local to_restore = {}
    local to_parse = {}
    local file_idx = 1

    local function classify_batch()
      local batch_end = math.min(file_idx + STAT_BATCH - 1, #files)

      for i = file_idx, batch_end do
        local abs_path = files[i]
        local stat = vim.uv.fs_stat(abs_path)
        if stat then
          local rel_path = abs_path:sub(#self.vault_path + 2)
          local cached = cached_notes[rel_path]
          if cached and cached.mtime == stat.mtime.sec * 1000 and cached.size == stat.size then
            table.insert(to_restore, cached)
          else
            table.insert(to_parse, { abs_path = abs_path, stat = stat })
          end
        end
      end

      file_idx = batch_end + 1

      if file_idx <= #files then
        vim.schedule(classify_batch)
      else
        -- Phase 3: process (restore + parse) in batches
        local all_work = {}
        for _, cached in ipairs(to_restore) do
          table.insert(all_work, { type = "restore", data = cached })
        end
        for _, entry in ipairs(to_parse) do
          table.insert(all_work, { type = "parse", data = entry })
        end

        local PROCESS_BATCH = 50
        local work_idx = 1

        local function process_batch()
          local batch_end2 = math.min(work_idx + PROCESS_BATCH - 1, #all_work)

          for i = work_idx, batch_end2 do
            local item = all_work[i]
            if item.type == "restore" then
              local note = deserialize_note(item.data)
              self.notes[note.path] = note
              add_to_indices(self, note)
            else
              local note = create_note_data(self.vault_path, item.data.abs_path, item.data.stat)
              if note then
                self.notes[note.path] = note
                add_to_indices(self, note)
              end
            end
          end

          work_idx = batch_end2 + 1

          if work_idx <= #all_work then
            vim.schedule(process_batch)
          else
            if callback then
              callback()
            end
          end
        end

        if #all_work > 0 then
          vim.schedule(process_batch)
        else
          if callback then
            callback()
          end
        end
      end
    end

    if #files > 0 then
      vim.schedule(classify_batch)
    else
      if callback then
        callback()
      end
    end
  end)
end

--- Get a note by path
---@param self NoteIndex
---@param path string Vault-relative path
---@return NoteData|nil
function NoteIndex:get(path)
  return self.notes[path]
end

--- Get all notes
---@param self NoteIndex
---@return table<string, NoteData>
function NoteIndex:all()
  return self.notes
end

--- Update a single file in the index
---@param self NoteIndex
---@param path string Vault-relative path
function NoteIndex:update_file(path)
  local abs_path = self.vault_path .. "/" .. path
  local stat = vim.uv.fs_stat(abs_path)

  if not stat then
    self:remove_file(path)
    return
  end

  -- Remove old note from indices if it exists
  local old_note = self.notes[path]
  if old_note then
    remove_from_indices(self, old_note)
  end

  -- Create new note data
  local note = create_note_data(self.vault_path, abs_path, stat)
  if note then
    self.notes[path] = note
    add_to_indices(self, note)
  else
    self.notes[path] = nil
  end
end

--- Remove a file from the index
---@param self NoteIndex
---@param path string Vault-relative path
function NoteIndex:remove_file(path)
  local note = self.notes[path]
  if not note then
    return
  end

  remove_from_indices(self, note)
  self.notes[path] = nil
end

return M
