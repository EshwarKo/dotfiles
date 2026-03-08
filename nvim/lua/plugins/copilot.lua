return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      suggestion = { enabled = true, auto_trigger = true, keymap = {
        accept = "<C-f>",
        next = "<C-Right>",
        prev = "<C-Down>",
        dismiss = "<C-e>",
      }},
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        help = false,
        gitcommit = true,
        ["*"] = true,
      },
    })
  end,
}
