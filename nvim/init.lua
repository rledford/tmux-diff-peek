vim.g.mapleader = " "

local env_clipboard = vim.env.TMUX_DIFF_PEEK_CLIPBOARD_CMD
local env_export_key = vim.env.TMUX_DIFF_PEEK_EXPORT_KEY

vim.g.tmux_diff_peek_clipboard_cmd =
  (env_clipboard ~= nil and env_clipboard ~= "") and env_clipboard or "pbcopy"
vim.g.tmux_diff_peek_export_key =
  (env_export_key ~= nil and env_export_key ~= "") and env_export_key or "<leader>x"

vim.opt.laststatus = 0
vim.opt.shortmess:append("I")
vim.opt.cmdheight = 1
vim.opt.swapfile = false
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.api.nvim_create_autocmd("BufReadPost", {
  once = true,
  callback = function(args)
    local diff_buf = args.buf
    vim.bo[diff_buf].filetype = "diff"
    vim.bo[diff_buf].modifiable = false
    vim.bo[diff_buf].readonly = true
    require("diff_peek.session").start(diff_buf)
  end,
})
