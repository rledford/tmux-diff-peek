local M = {}

local cache = {}

local function match_hunk_header(line)
  local b_start = line:match("^@@ %-%d+,%d+ %+(%d+),%d+ @@")
  if b_start then
    return tonumber(b_start)
  end

  b_start = line:match("^@@ %-%d+ %+(%d+),%d+ @@")
  if b_start then
    return tonumber(b_start)
  end

  b_start = line:match("^@@ %-%d+,%d+ %+(%d+) @@")
  if b_start then
    return tonumber(b_start)
  end

  b_start = line:match("^@@ %-%d+ %+(%d+) @@")
  if b_start then
    return tonumber(b_start)
  end

  return nil
end

local function is_hunk_header(line)
  return line:match("^@@ ") ~= nil
end

function M.build(lines)
  local map = {}
  local current_path = nil
  local current_hunk_id = 0
  local in_hunk = false
  local counter = 0
  local file_block_unmappable = false
  local saw_post_image_warning = {}

  for i, line in ipairs(lines) do
    map[i] = false

    if line:match("^diff %-%-git ") then
      current_path = nil
      in_hunk = false
      file_block_unmappable = false
      counter = 0

      local b_path = line:match("^diff %-%-git a/.- b/(.+)$")
      if b_path then
        current_path = b_path
      end
    elseif line:match("^%+%+%+ ") then
      in_hunk = false
      if line == "+++ /dev/null" then
        current_path = nil
      else
        local p = line:match("^%+%+%+ b/(.+)$")
        if p then
          current_path = p
        else
          if not saw_post_image_warning[line] then
            saw_post_image_warning[line] = true
            if vim and vim.notify and vim.log then
              vim.notify(
                "diff-peek: parser saw post-image without b/ prefix",
                vim.log.levels.WARN
              )
            end
          end
          file_block_unmappable = true
        end
      end
    elseif line:match("^%-%-%- ") then
      in_hunk = false
    elseif line:match("^Binary files .* differ$") then
      file_block_unmappable = true
      in_hunk = false
    elseif line:match("^similarity index 100%%") then
      file_block_unmappable = true
    elseif is_hunk_header(line) then
      if file_block_unmappable or not current_path then
        in_hunk = false
      else
        local b_start = match_hunk_header(line)
        if b_start then
          current_hunk_id = current_hunk_id + 1
          counter = b_start
          in_hunk = true
        else
          in_hunk = false
        end
      end
    elseif in_hunk and not file_block_unmappable and current_path then
      local prefix = line:sub(1, 1)
      if prefix == "+" then
        map[i] = {
          path = current_path,
          hunk_id = current_hunk_id,
          file_line = counter,
          kind = "added",
        }
        counter = counter + 1
      elseif prefix == "-" then
        map[i] = {
          path = current_path,
          hunk_id = current_hunk_id,
          file_line = nil,
          kind = "removed",
        }
      elseif prefix == " " then
        map[i] = {
          path = current_path,
          hunk_id = current_hunk_id,
          file_line = counter,
          kind = "context",
        }
        counter = counter + 1
      elseif line:match("^\\") then
        map[i] = false
      else
        in_hunk = false
      end
    end
  end

  return map
end

function M.attach(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local map = M.build(lines)
  cache[bufnr] = map
  return map
end

function M.line_to_location(bufnr, lnum)
  local map = cache[bufnr]
  if not map then
    return nil
  end
  local entry = map[lnum]
  if not entry then
    return nil
  end
  return entry
end

function M.selection_to_range(bufnr, s, e)
  local map = cache[bufnr]
  if not map then
    return nil, "no_mappable"
  end

  if s > e then
    s, e = e, s
  end

  local mappable = {}
  for i = s, e do
    local entry = map[i]
    if entry then
      table.insert(mappable, entry)
    end
  end

  if #mappable == 0 then
    return nil, "no_mappable"
  end

  local path = mappable[1].path
  local hunk_id = mappable[1].hunk_id
  for _, entry in ipairs(mappable) do
    if entry.path ~= path then
      return nil, "multi_file"
    end
    if entry.hunk_id ~= hunk_id then
      return nil, "multi_hunk"
    end
  end

  local start_file_line = nil
  local end_file_line = nil
  for _, entry in ipairs(mappable) do
    if entry.file_line ~= nil then
      if start_file_line == nil or entry.file_line < start_file_line then
        start_file_line = entry.file_line
      end
      if end_file_line == nil or entry.file_line > end_file_line then
        end_file_line = entry.file_line
      end
    end
  end

  if start_file_line == nil then
    return nil, "removed_only"
  end

  return {
    path = path,
    hunk_id = hunk_id,
    start_file_line = start_file_line,
    end_file_line = end_file_line,
  }, nil
end

function M._clear_cache_for_tests()
  cache = {}
end

return M
