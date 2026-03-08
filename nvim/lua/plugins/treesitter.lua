return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = { "lua", "python", "cpp", "haskell", "latex", "bibtex", "scala", "java" },
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = { "tex", "latex", "plaintex" },
      },
      indent = {
        enable = true,
        disable = { "latex", "tex", "plaintex" },
      },
    })
  end,
}
