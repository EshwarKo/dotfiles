-- lua/plugins/lsp.lua
return {
  "neovim/nvim-lspconfig",
  lazy = false,
  dependencies = {
    -- NOTE: official repos
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
  },

  config = function()
    -- Mason: install servers, but don't auto-enable (we enable manually below)
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = { "lua_ls", "pyright", "clangd", "hls", "texlab"},
      automatic_installation = true,
      automatic_enable = false,
    })

    -- nvim-cmp capabilities
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- on_attach: buffer-local keymaps
    local on_attach = function(_, bufnr)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end
      map("n", "gd", vim.lsp.buf.definition,           "Goto Definition")
      map("n", "gr", vim.lsp.buf.references,           "References")
      map("n", "K",  vim.lsp.buf.hover,                "Hover Docs")
      map("n", "<leader>rn", vim.lsp.buf.rename,       "Rename Symbol")
      map("n", "<leader>ca", vim.lsp.buf.code_action,  "Code Action")
      map("n", "[d", vim.diagnostic.goto_prev,         "Prev Diagnostic")
      map("n", "]d", vim.diagnostic.goto_next,         "Next Diagnostic")
      map("n", "<leader>ld", vim.diagnostic.open_float,"Line Diagnostics")
      map("n", "<leader>lf", function() vim.lsp.buf.format({ async = false }) end, "Format Buffer")
    end

    -- Metals (Scala) uses nvim-metals, not mason-lspconfig
    pcall(function()
      require("plugins.metals-config").setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })
    end)

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
          workspace = { checkThirdParty = false },
          telemetry = { enable = false },
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

    -- LaTeX (texlab) — tuned for macOS + VimTeX/Skim
    vim.lsp.config("texlab", {
      capabilities = capabilities,
      on_attach = on_attach,
      settings = {
        texlab = {
          build = { onSave = false },  -- let VimTeX handle builds
          latexFormatter = "latexindent",
          latexindent = { modifyLineBreaks = true },
          forwardSearch = { executable = "skim", args = {} },
        },
      },
    })

    -- Enable servers (manual control since automatic_enable=false)
    vim.lsp.enable("hls")
    vim.lsp.enable("lua_ls")
    vim.lsp.enable("pyright")
    vim.lsp.enable("clangd")
    vim.lsp.enable("texlab")
  end,
}
