-- lua/plugins/autopairs.lua
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  dependencies = { "hrsh7th/nvim-cmp" }, -- optional but recommended
  config = function()
    -- === Basic setup ===
    local npairs = require("nvim-autopairs")
    npairs.setup({
      check_ts = true,          -- use treesitter to avoid pairing in comments/strings
      ts_config = {
        lua = { "string" },
        javascript = { "template_string" },
        java = false,
      },
      disable_filetype = { "TelescopePrompt", "spectre_panel" },
    })

    -- === Integration with nvim-cmp ===
    local cmp_status_ok, cmp = pcall(require, "cmp")
    if cmp_status_ok then
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end

    -- === Optional: extra rules for specific filetypes ===
    local Rule = require("nvim-autopairs.rule")

    -- Example: add TeX/LaTeX math pair $
    npairs.add_rules({
      Rule("$", "$", { "tex", "latex" })
        :with_pair(function(opts)
          -- only pair $ if not after a letter or another $
          local prev_char = opts.line:sub(opts.col - 1, opts.col - 1)
          if prev_char:match("[%w%%]") then
            return false
          end
          return true
        end),
    })
  end,
}
