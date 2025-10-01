-- Leader

vim.g.mapleader = " "

-- Numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- True Colours
vim.opt.termguicolors = true

-- Default: 2 spaces
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

-- Python: 4 spaces
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})

require("config.lazy")
