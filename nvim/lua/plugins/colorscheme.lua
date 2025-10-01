return {
  -- The main Gruvbox (Lua port, stable & popular)
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      contrast = "soft", -- can be "hard", "medium", or "soft"
      transparent_mode = false,
    },
    config = function(_, opts)
      require("gruvbox").setup(opts)
      vim.o.background = "dark"          -- or "light" for light mode
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  -- Alternative: gruvbox-material (a darker, richer variant)
  -- { 
  --   "sainnhe/gruvbox-material",
  --   priority = 1000,
  --   lazy = false,
  --   config = function()
  --     vim.g.gruvbox_material_background = "medium" -- soft | medium | hard
  --     vim.g.gruvbox_material_enable_bold = 1
  --     vim.g.gruvbox_material_enable_italic = 1
  --     vim.cmd.colorscheme("gruvbox-material")
  --   end,
  -- },

  -- Alternative: gruvbox-baby (pastel, softer look)
  -- {
  --   "luisiacc/gruvbox-baby",
  --   priority = 1000,
  --   lazy = false,
  --   config = function()
  --     vim.g.gruvbox_baby_transparent_mode = 1
  --     vim.cmd.colorscheme("gruvbox-baby")
  --   end,
  -- },
}

