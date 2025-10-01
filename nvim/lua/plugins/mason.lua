-- lua/plugins/mason.lua
return {
  "williamboman/mason.nvim",
  lazy = false,
  build = ":MasonUpdate", -- keep registry up to date
  config = function()
    require("mason").setup()
  end,
}

