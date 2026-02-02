local M = {}

--- Build default NoteData with sensible defaults, merge overrides
---@param overrides table|nil
---@return table NoteData
function M.make_note_data(overrides)
  overrides = overrides or {}
  local path = overrides.path or 'notes/test.md'
  local basename = path:match('([^/]+)%.%w+$') or 'test'
  local name = path:match('([^/]+)$') or 'test.md'
  local folder = path:match('^(.+)/') or ''

  local tags = overrides.tags or {}
  local tag_set = {}
  for _, t in ipairs(tags) do
    tag_set[t:lower()] = true
  end

  local links = overrides.links or {}
  local outgoing_link_set = {}
  for _, link in ipairs(links) do
    local p = type(link) == 'table' and link.path or link
    outgoing_link_set[p] = true
  end

  local note = {
    path = path,
    name = name,
    basename = basename,
    folder = folder,
    ext = 'md',
    ctime = overrides.ctime or 1706054400000,
    mtime = overrides.mtime or 1706140800000,
    size = overrides.size or 100,
    frontmatter = overrides.frontmatter or {},
    tags = tags,
    tag_set = overrides.tag_set or tag_set,
    links = overrides.links or {},
    outgoing_link_set = overrides.outgoing_link_set or outgoing_link_set,
  }

  -- Allow overriding computed fields
  for k, v in pairs(overrides) do
    if k ~= 'tags' and k ~= 'links' then
      note[k] = v
    end
  end

  return note
end

--- Build a mock NoteIndex from an array of NoteData tables
---@param notes table[] Array of NoteData
---@return table NoteIndex mock with :get(), :all(), by_tag, by_folder
function M.make_note_index(notes)
  local notes_by_path = {}
  local by_tag = {}
  local by_folder = {}

  for _, note in ipairs(notes) do
    notes_by_path[note.path] = note

    -- Build by_tag index
    if note.tag_set then
      for tag, _ in pairs(note.tag_set) do
        by_tag[tag] = by_tag[tag] or {}
        by_tag[tag][note.path] = true
      end
    end

    -- Build by_folder index
    if note.folder and note.folder ~= '' then
      by_folder[note.folder] = by_folder[note.folder] or {}
      by_folder[note.folder][note.path] = true
    end
  end

  return {
    by_tag = by_tag,
    by_folder = by_folder,
    get = function(_, path)
      return notes_by_path[path]
    end,
    all = function(_)
      return notes_by_path
    end,
  }
end

--- Build a SerializedEntry with defaults
---@param overrides table|nil
---@return table SerializedEntry
function M.make_serialized_entry(overrides)
  overrides = overrides or {}
  return {
    file = overrides.file or {
      path = 'notes/test.md',
      name = 'test.md',
      basename = 'test',
    },
    values = overrides.values or {},
  }
end

--- Get absolute path to a fixture file
---@param relative string Relative path from tests/fixtures/
---@return string
function M.fixture_path(relative)
  local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h')
  return root .. '/fixtures/' .. relative
end

--- Read a fixture file and return its contents as a string
---@param relative string Relative path from tests/fixtures/
---@return string
function M.read_fixture(relative)
  local path = M.fixture_path(relative)
  local lines = vim.fn.readfile(path)
  return table.concat(lines, '\n')
end

return M
