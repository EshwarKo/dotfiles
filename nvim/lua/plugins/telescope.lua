return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },

  cmd = "Telescope", -- lazy-load when you run :Telescope
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>",  desc = "Grep (rg)" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>",    desc = "Find buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>",  desc = "Help" },
  },

  config = function()
    local telescope = require("telescope")
    telescope.setup({
      defaults = {
        path_display = { "smart" },
        layout_config = { horizontal = { preview_width = 0.6 } },
      },
    })
  end,
}

