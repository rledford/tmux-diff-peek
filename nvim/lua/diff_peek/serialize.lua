local M = {}

local function is_blank(line)
  return line == nil or line:match("^%s*$") ~= nil
end

local function is_header(line)
  return line ~= nil and line:match("^## ") ~= nil
end

local function find_block_starts(lines)
  local starts = {}
  for i, line in ipairs(lines) do
    if is_header(line) then
      if i == 1 then
        table.insert(starts, i)
      else
        local prev = lines[i - 1]
        if is_blank(prev) then
          table.insert(starts, i)
        end
      end
    end
  end
  return starts
end

local function trim_trailing_blanks(list)
  while #list > 0 and is_blank(list[#list]) do
    table.remove(list)
  end
  return list
end

function M.collect(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local starts = find_block_starts(lines)

  if #starts == 0 then
    return { text = "", count = 0 }
  end

  local rendered_blocks = {}

  for idx, block_start in ipairs(starts) do
    local block_end
    if idx == #starts then
      block_end = #lines
    else
      block_end = starts[idx + 1] - 1
    end

    local block_lines = {}
    for i = block_start, block_end do
      table.insert(block_lines, lines[i])
    end
    block_lines = trim_trailing_blanks(block_lines)

    local close_fence_idx = nil
    for i, line in ipairs(block_lines) do
      if line == "```" then
        close_fence_idx = i
        break
      end
    end

    if close_fence_idx ~= nil then
      local body_lines = {}
      for i = close_fence_idx + 1, #block_lines do
        table.insert(body_lines, block_lines[i])
      end

      local body_is_empty = true
      for _, l in ipairs(body_lines) do
        if not is_blank(l) then
          body_is_empty = false
          break
        end
      end

      if not body_is_empty then
        table.insert(rendered_blocks, table.concat(block_lines, "\n"))
      end
    end
  end

  if #rendered_blocks == 0 then
    return { text = "", count = 0 }
  end

  local joined = table.concat(rendered_blocks, "\n\n")
  return { text = joined, count = #rendered_blocks }
end

return M
