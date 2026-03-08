local ls = require("luasnip")
local s  = ls.snippet
local t  = ls.text_node
local i  = ls.insert_node
local rep = require("luasnip.extras").rep

local function in_mathzone()
  return vim.fn.exists("*vimtex#syntax#in_mathzone") == 1
         and vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

return {
  -- Stop '.' auto-expansion
  s(".", { t(".") }),

  -- If you still want \ldots, make it explicit:
  s({ trig = "...", wordTrig = false }, { t("\\dots") }),

  -- Handy environment helper
  s("env", {
    t("\\begin{"), i(1, "env"), t({"}", "\t"}),  -- cursor starts here
    i(0),                                        -- body (next <Tab> lands here)
    t({"", "\\end{"}), rep(1), t("}"),           -- mirrors whatever you typed in i(1)
  }),

   -- // → \frac{…}{…}
  s(
    { trig = "//", wordTrig = false, priority = 10000 },
    fmt("\\frac{{{}}}{{{}}}", {
      i(1, "numerator"),   -- first field, Tab here first
      i(2, "denominator"), -- Shift-Tab goes back
    }),
    { condition = in_mathzone }  -- remove this line if you want it everywhere
  ),

  -- inline math
  s("mm", { t("\\("), i(1), t("\\)") }),

  -- display math
  s("dm", { t({"\\[", "\t"}), i(1), t({"", "\\]"}) }),

  -- mathBB
  s("nn", { t("\\mathbb{N}") }),
  s("rr", { t("\\mathbb{R}") }),
  s("zz", { t("\\mathbb{Z}") }),
  s("qq", { t("\\mathbb{Q}") }),
  s("cc", { t("\\mathbb{C}") }),

  -- set notation
  s("dset", {
    t("\\{"), i(1, "x"), t(" \\mid "), i(2, "condition"), t("\\}")
  }),

  s(
    { trig = "seq", wordTrig = true },
    {
      t("\\{"),
      i(1, "x"), t("_{1}, "),
      rep(1),   t("_{2}, \\ldots, "),
      rep(1),   t("_{"),
      i(2, "n"), t("}\\}"),
    },
    { condition = in_mathzone }
  ),

  -- {1, 2, ..., n}  — choose the final symbol (n by default)
  s(
    { trig = "seq1", wordTrig = true },
    { t("\\{1, 2, \\ldots, "), i(1, "n"), t("\\}") },
    { condition = in_mathzone }
  ),
}

