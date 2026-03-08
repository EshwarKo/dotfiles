return {
  "scalameta/nvim-metals",
  dependencies = { "nvim-lua/plenary.nvim" },
  ft = { "scala", "sbt", "java" },
  config = function()
    local metals = require("metals")
    local config = metals.bare_config()

    -- Reuse your existing cmp capabilities if available
    local ok, cmp = pcall(require, "cmp_nvim_lsp")
    if ok then
      config.capabilities = cmp.default_capabilities()
    end

    config.settings = {
      showImplicitArguments = true,
      showInferredType = true,
      superMethodLensesEnabled = true,
    }

    config.init_options.statusBarProvider = "on"

    local group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "scala", "sbt", "java" },
      callback = function()
        metals.initialize_or_attach(config)
      end,
      group = group,
    })
  end,
}

