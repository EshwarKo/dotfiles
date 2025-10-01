return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",   -- auto update parsers when installing
  event = { "BufReadPost", "BufNewFile" }, -- lazy-load only when needed

  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = { "lua", "python", "cpp", "haskell", "latex" }, -- add more later
      highlight = { enable = true },  -- syntax highlighting
      indent = { enable = true },     -- smarter indentation
    })
  end,
}

