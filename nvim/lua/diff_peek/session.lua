local M = {}

local parser = require("diff_peek.parser")

local state = {
  diff_buf = nil,
  comments_buf = nil,
}

local rejection_messages = {
  multi_file = "diff-peek: selection spans multiple files",
  multi_hunk = "diff-peek: selection spans multiple hunks",
  removed_only = "diff-peek: selection contains only removed lines",
  no_mappable = "diff-peek: selection has no mappable diff lines",
}

local function find_or_open_comments_window()
  local win = vim.fn.bufwinid(state.comments_buf)
  if win ~= -1 then
    return win
  end

  vim.cmd("rightbelow vsplit")
  vim.api.nvim_set_current_buf(state.comments_buf)
  return vim.fn.bufwinid(state.comments_buf)
end

local function exit_visual_mode()
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)
end

function M.handle_selection()
  local start_lnum = vim.fn.line("v")
  local end_lnum = vim.fn.line(".")
  if start_lnum > end_lnum then
    start_lnum, end_lnum = end_lnum, start_lnum
  end

  exit_visual_mode()

  if start_lnum == 0 or end_lnum == 0 then
    vim.notify("diff-peek: no selection captured", vim.log.levels.WARN)
    return
  end

  local range, reason = parser.selection_to_range(state.diff_buf, start_lnum, end_lnum)
  if reason then
    vim.notify(rejection_messages[reason] or ("diff-peek: " .. reason), vim.log.levels.WARN)
    return
  end

  if not range then
    vim.notify("diff-peek: selection rejected", vim.log.levels.WARN)
    return
  end

  local selection_lines = vim.api.nvim_buf_get_lines(state.diff_buf, start_lnum - 1, end_lnum, false)

  local header
  if range.start_file_line == range.end_file_line then
    header = string.format("## %s:%d", range.path, range.start_file_line)
  else
    header = string.format("## %s:%d-%d", range.path, range.start_file_line, range.end_file_line)
  end

  local current_lines = vim.api.nvim_buf_get_lines(state.comments_buf, 0, -1, false)
  local is_empty_buffer = #current_lines == 0
    or (#current_lines == 1 and current_lines[1] == "")

  local block = {}
  if not is_empty_buffer then
    local last_line = current_lines[#current_lines] or ""
    if last_line ~= "" then
      table.insert(block, "")
    end
    table.insert(block, "")
  end
  table.insert(block, header)
  table.insert(block, "```diff")
  for _, line in ipairs(selection_lines) do
    table.insert(block, line)
  end
  table.insert(block, "```")
  table.insert(block, "")

  vim.bo[state.comments_buf].modifiable = true
  if is_empty_buffer then
    vim.api.nvim_buf_set_lines(state.comments_buf, 0, -1, false, block)
  else
    vim.api.nvim_buf_set_lines(state.comments_buf, -1, -1, false, block)
  end

  local body_line = vim.api.nvim_buf_line_count(state.comments_buf)

  local win = find_or_open_comments_window()
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { body_line, 0 })
  vim.cmd("startinsert")
end

function M.export()
  local serialize = require("diff_peek.serialize")
  local clipboard = require("diff_peek.clipboard")

  local result = serialize.collect(state.comments_buf)
  if result.count == 0 then
    vim.notify("diff-peek: no comments to export", vim.log.levels.WARN)
    return
  end

  local ok, err = clipboard.write(result.text)
  if not ok then
    vim.notify("diff-peek: clipboard write failed: " .. (err or "unknown"), vim.log.levels.ERROR)
    return
  end

  local plural = result.count == 1 and "" or "s"
  vim.notify(
    string.format("diff-peek: copied %d comment block%s", result.count, plural),
    vim.log.levels.INFO
  )
end

function M.start(diff_buf)
  state.diff_buf = diff_buf

  local comments_buf = vim.api.nvim_create_buf(false, true)
  state.comments_buf = comments_buf

  vim.bo[comments_buf].buftype = "nofile"
  vim.bo[comments_buf].bufhidden = "hide"
  vim.bo[comments_buf].filetype = "markdown"
  vim.bo[comments_buf].swapfile = false
  vim.bo[comments_buf].modifiable = true

  parser.attach(diff_buf)

  vim.cmd("rightbelow vsplit")
  vim.api.nvim_set_current_buf(comments_buf)

  local comments_win = vim.api.nvim_get_current_win()
  vim.wo[comments_win].winhighlight = "Normal:NormalFloat,SignColumn:NormalFloat"
  vim.wo[comments_win].cursorline = true

  vim.cmd("wincmd h")
  local diff_win = vim.api.nvim_get_current_win()
  vim.wo[diff_win].cursorline = false

  vim.keymap.set({ "x", "v" }, "<CR>", M.handle_selection, {
    buffer = diff_buf,
    silent = true,
  })

  local function bind_pane_switch(buf)
    vim.keymap.set("n", "<C-h>", "<cmd>wincmd h<CR>", { buffer = buf, silent = true })
    vim.keymap.set("n", "<C-l>", "<cmd>wincmd l<CR>", { buffer = buf, silent = true })
    vim.keymap.set("i", "<C-h>", "<Esc><cmd>wincmd h<CR>", { buffer = buf, silent = true })
    vim.keymap.set("i", "<C-l>", "<Esc><cmd>wincmd l<CR>", { buffer = buf, silent = true })
    vim.keymap.set("x", "<C-h>", "<Esc><cmd>wincmd h<CR>", { buffer = buf, silent = true })
    vim.keymap.set("x", "<C-l>", "<Esc><cmd>wincmd l<CR>", { buffer = buf, silent = true })
  end
  bind_pane_switch(diff_buf)
  bind_pane_switch(comments_buf)

  vim.api.nvim_create_user_command("DiffPeekExport", function()
    M.export()
  end, {})

  local export_key = vim.g.tmux_diff_peek_export_key or "<leader>x"
  if export_key ~= "" then
    vim.keymap.set("n", export_key, "<cmd>DiffPeekExport<CR>", {
      buffer = comments_buf,
      silent = true,
    })
  end

  return {
    diff_buf = diff_buf,
    comments_buf = comments_buf,
  }
end

return M
