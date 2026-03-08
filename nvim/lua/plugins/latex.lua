-- lua/plugins/latex.lua
return {
  {
    "lervag/vimtex",
    lazy = false, -- load early so filetype hooks work
    init = function()
      -- ──────────────────────────────────────────────
      -- Syntax & Conceal
      -- ──────────────────────────────────────────────
      -- Disable Vim’s built-in TeX conceal (it hides math delimiters)
      vim.g.tex_conceal = ""
      -- Enable VimTeX’s own prettier conceal rules
      vim.g.vimtex_syntax_conceal = {
        accents = 1,
        cites = 1,
        fancy = 1,
        greek = 1,
        math_delimiters = 0, -- keep \( \) \[ \] visible
      }

      -- Enable conceal visually for TeX buffers
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "plaintex", "latex" },
        callback = function()
          vim.wo.conceallevel = 2
          vim.wo.concealcursor = "nc" -- show conceals in normal/command mode
        end,
      })

      -- ──────────────────────────────────────────────
      -- VimTeX Core Settings
      -- ──────────────────────────────────────────────
      vim.g.vimtex_view_method = "skim"   -- viewer for macOS
      vim.g.vimtex_quickfix_mode = 0      -- disable auto-quickfix
      vim.g.vimtex_lint_enabled = 0       -- optional: disable VimTeX’s chktex linter

      -- Compiler (latexmk)
      vim.g.vimtex_compiler_latexmk = {
        options = {
          "-pdf",
          "-interaction=nonstopmode",
          "-synctex=1",
          "-file-line-error",
        },
      }

      -- ──────────────────────────────────────────────
      -- Format on Save
      -- ──────────────────────────────────────────────
      local fmt = vim.api.nvim_create_augroup("LaTeXFmt", { clear = true })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = fmt,
        pattern = "*.tex",
        callback = function()
          if vim.fn.executable("latexindent") == 1 then
            local view = vim.fn.winsaveview()
            vim.cmd([[silent keepjumps %!latexindent -]])
            vim.fn.winrestview(view)
          end
        end,
      })

      -- ──────────────────────────────────────────────
      -- Keymaps
      -- ──────────────────────────────────────────────
      vim.keymap.set("n", "<leader>lc", "<cmd>VimtexCompile<CR>", { desc = "LaTeX: Compile (once/start)" })
      vim.keymap.set("n", "<leader>ll", "<plug>(vimtex-compile)", { desc = "LaTeX: Toggle continuous" })
      vim.keymap.set("n", "<leader>lk", "<cmd>VimtexStop<CR>",    { desc = "LaTeX: Stop compiler" })
      vim.keymap.set("n", "<leader>lv", "<cmd>VimtexView<CR>",    { desc = "LaTeX: View in Skim" })
      vim.keymap.set("n", "<leader>le", "<cmd>VimtexErrors<CR>",  { desc = "LaTeX: Show errors" })
    end,
  },
}
