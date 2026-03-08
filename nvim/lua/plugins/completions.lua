-- lua/plugins/completion.lua
return {
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
      vim.opt.completeopt = { "menu", "menuone", "noselect" }

      -- LuaSnip base config (optional but nice)
      local luasnip = require("luasnip")
      luasnip.config.set_config({
        history = true,
        updateevents = "TextChanged,TextChangedI",
        enable_autosnippets = true,
      })

      -- Load community VSCode-style snippets
      require("luasnip.loaders.from_vscode").lazy_load()

      -- 👉 Load YOUR local snippets (Lua files in ~/.config/nvim/snippets)
      require("luasnip.loaders.from_lua").load({
        paths = vim.fn.stdpath("config") .. "/snippets",
      })

      -- Helpers: edit & reload your snippet files quickly
      vim.api.nvim_create_user_command("EditSnippet", function()
        local ft = vim.bo.filetype
        local p = vim.fn.stdpath("config") .. "/snippets/" .. ft .. ".lua"
        vim.cmd("edit " .. p)
      end, {})

      vim.api.nvim_create_user_command("ReloadSnippets", function()
        require("luasnip.loaders.from_lua").load({
          paths = vim.fn.stdpath("config") .. "/snippets",
        })
        require("luasnip.loaders.from_vscode").lazy_load()
        print("Snippets reloaded")
      end, {})

      local cmp     = require("cmp")
      local lspkind = require("lspkind")

      -- Commandline completion
      cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "path" }, { name = "cmdline" } },
      })

      -- Insert mode completion
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
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
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "nvim_lsp_signature_help" },
          { name = "luasnip" },
        }, {
          { name = "path" },
          { name = "buffer" },
        }),
      })
    end,
  },
}
