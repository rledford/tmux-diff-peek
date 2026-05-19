local M = {}

function M.write(text)
  local cmd = vim.g.tmux_diff_peek_clipboard_cmd
  if cmd == nil or cmd == "" then
    return false, "no clipboard command configured"
  end

  local cmd_list = vim.split(cmd, "%s+", { trimempty = true })
  if #cmd_list == 0 then
    return false, "no clipboard command configured"
  end

  local out = vim.fn.system(cmd_list, text)
  if vim.v.shell_error == 0 then
    return true, nil
  end

  local err
  if out ~= nil and out ~= "" then
    err = out
  else
    err = string.format("exit %d", vim.v.shell_error)
  end
  return false, err
end

return M
