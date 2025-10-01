-- lua/plugins/completion.lua
return {
  -- Completion engine + sources + snippets
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "saadparwaiz1/cmp_luasnip",
      { "L3MON4D3/LuaSnip", version = "v2.*", build = "make install_jsregexp" },
      "rafamadriz/friendly-snippets",
      "onsails/lspkind.nvim",
      "hrsh7th/cmp-nvim-lsp-signature-help",
    },
    config = function()
      -- Popup behavior
      vim.opt.completeopt = { "menu", "menuone", "noselect" }

      -- Load community + VSCode-style snippets
      require("luasnip.loaders.from_vscode").lazy_load()

      local cmp      = require("cmp")
      local luasnip  = require("luasnip")
      local lspkind  = require("lspkind")

      -- Optional: completion on / and : commandline
      cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "path" }, { name = "cmdline" } },
      })

      -- Main insert-mode completion
      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        formatting = {
          format = lspkind.cmp_format({ mode = "symbol_text", maxwidth = 50, ellipsis_char = "…" }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping(function(fb)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fb()
            end
          end, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(function(fb)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fb()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources(
          {
            { name = "nvim_lsp" },
            { name = "nvim_lsp_signature_help" },
            { name = "luasnip" },
          },
          {
            { name = "path" },
            { name = "buffer" },
          }
        ),
      })
    end,
  },

  -- Tell all LSP servers about cmp's extra capabilities (new API style)
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local caps = require("cmp_nvim_lsp").default_capabilities()
      -- Apply to every server you define via vim.lsp.config("server", {...})
      vim.lsp.config("*", { capabilities = caps })
    end,
  },
}
