-- lua/plugins/mason.lua
-- Mason is set up and configured in lsp.lua (which depends on it).
-- This file just ensures the registry stays up to date.
return {
  "mason-org/mason.nvim",
  lazy = false,
  build = ":MasonUpdate",
}

