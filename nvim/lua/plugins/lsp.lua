-- lua/plugins/lsp.lua
return {
  "neovim/nvim-lspconfig",  -- still useful: ships default server configs Neovim can merge
  lazy = false,
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
  },

  config = function()
    -- 1) Mason installs servers; mason-lspconfig can auto-enable them (native API)
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = { "lua_ls", "pyright", "clangd", "hls", "texlab" },
      -- With v2, this plugin’s scope is slim: install + (optionally) auto-enable
      -- It relies on the native API under the hood. :contentReference[oaicite:1]{index=1}
    })

    -- 2) Capabilities from nvim-cmp (pass into vim.lsp.config)
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- 3) Buffer-local keymaps on attach
    local on_attach = function(_, bufnr)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end
      map("n", "gd", vim.lsp.buf.definition,        "Goto Definition")
      map("n", "gr", vim.lsp.buf.references,        "References")
      map("n", "K",  vim.lsp.buf.hover,             "Hover Docs")
      map("n", "<leader>rn", vim.lsp.buf.rename,    "Rename Symbol")
      map("n", "<leader>ca", vim.lsp.buf.code_action,"Code Action")
      map("n", "[d", vim.diagnostic.goto_prev,      "Prev Diagnostic")
      map("n", "]d", vim.diagnostic.goto_next,      "Next Diagnostic")
    end

    -- 4) Define/extend server configs with the NEW native API (0.11+)
    --    Neovim merges these with shipped defaults. Then enable them.
    --    Docs: :h news-0.11, :h lsp, and nvim-lspconfig README. :contentReference[oaicite:2]{index=2}

    -- Haskell (HLS)
    vim.lsp.config("hls", {
      capabilities = capabilities,
      on_attach = on_attach,
      filetypes = { "haskell", "lhaskell", "cabal" },
    })

    -- Lua
    vim.lsp.config("lua_ls", {
      capabilities = capabilities,
      on_attach = on_attach,
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim", "require" } },
        },
      },
    })

    -- Python
    vim.lsp.config("pyright", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    -- C/C++
    vim.lsp.config("clangd", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    -- LaTeX
    vim.lsp.config("texlab", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    -- 5) Enable the servers so they auto-attach by filetype
    vim.lsp.enable("hls")
    vim.lsp.enable("lua_ls")
    vim.lsp.enable("pyright")
    vim.lsp.enable("clangd")
    vim.lsp.enable("texlab")
  end,
}
