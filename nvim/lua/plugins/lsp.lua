-- lua/plugins/lsp.lua
return {
  "neovim/nvim-lspconfig",
  lazy = false,
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },

  config = function()
    -- 1. Setup mason + mason-lspconfig
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = { "lua_ls", "pyright", "clangd", "hls", "texlab" },
      automatic_installation = true,
    })

    -- 2. Configure servers with the new API
    vim.lsp.config("lua_ls", {
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim", "require" } },
        },
      },
    })

    -- Example for others (no fancy settings)
    vim.lsp.config("pyright", {})
    vim.lsp.config("clangd", {})
    vim.lsp.config("hls", {})
    vim.lsp.config("texlab", {})

    -- 3. Buffer-local keymaps (applied when LSP attaches)
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

    -- 4. Apply `on_attach` globally
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        on_attach(client, args.buf)
      end,
    })
  end,
}
