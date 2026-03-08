-- lua/latex_project.lua
-- Registers :LatexNew {target_dir} [name="Title"] [author="Your Name"] [template="/path"]

local M = {}

function M.setup()
  local uv = vim.uv or vim.loop
  local fn = vim.fn

  local function notify(msg, level)
    vim.notify("[LaTeX] " .. msg, level or vim.log.levels.INFO)
  end
  local function join(...) return table.concat({ ... }, "/"):gsub("//+", "/") end
  local function exists(p) return uv.fs_stat(p) ~= nil end
  local function is_dir(p) local s = uv.fs_stat(p); return s and s.type == "directory" end
  local function mkdir_p(p)
    if exists(p) then return true end
    local parent = p:match("(.+)/[^/]+$")
    if parent and not exists(parent) then mkdir_p(parent) end
    return uv.fs_mkdir(p, 493) -- 0755
  end

  local text_exts = { [".tex"]=true, [".bib"]=true, [".md"]=true }
  local special_names = { [".latexmkrc"]=true, ["Makefile"]=true, ["README.md"]=true }
  local function extname(p) return p:match("^.+(%.[^/%.]+)$") or "" end
  local function is_text_file(name) return text_exts[extname(name)] or special_names[vim.fs.basename(name)] or false end

  local function read_file(p)
    local fd = assert(uv.fs_open(p, "r", 438))
    local st = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, st.size, 0))
    uv.fs_close(fd)
    return data
  end
  local function write_file(p, data)
    mkdir_p(p:match("(.+)/[^/]+$") or ".")
    local fd = assert(uv.fs_open(p, "w", 420)) -- 0644
    assert(uv.fs_write(fd, data, 0))
    uv.fs_close(fd)
  end
  local function copy_file(src, dst)
    mkdir_p(dst:match("(.+)/[^/]+$") or ".")
    assert(uv.fs_copyfile(src, dst))
  end
  -- replaces {{{PROJECT}}}, {{{AUTHOR}}}, {{{DATE}}}, {{{YEAR}}}
  -- uses function replacements so special chars are safe, and adds LaTeX braces
  local function subst(s, v)
    local function br(x) return "{" .. x .. "}" end
    s = s:gsub("{{{PROJECT}}}", function() return br(v.PROJECT) end)
    s = s:gsub("{{{AUTHOR}}}",  function() return br(v.AUTHOR)  end)
    s = s:gsub("{{{DATE}}}",    function() return br(v.DATE)    end)
    s = s:gsub("{{{YEAR}}}",    function() return br(v.YEAR)    end)
    return s
  end

  local function copy_with_subst(src_dir, dst_dir, vars)
    for rel, t in vim.fs.dir(src_dir, { depth = math.huge }) do
      local src = join(src_dir, rel)
      local dst = join(dst_dir, rel)
      if t == "directory" then
        mkdir_p(dst)
      elseif t == "file" then
        if is_text_file(rel) then
          write_file(dst, subst(read_file(src), vars))
        else
          copy_file(src, dst)
        end
      end
    end
  end

  local function parse_kv(rest)
    local out = {}
    for k, v in rest:gmatch('(%w+)%s*=%s*"([^"]-)"') do out[k] = v end
    for k, v in rest:gmatch("(%w+)%s*=%s*([^%s]+)") do if out[k] == nil then out[k] = v end end
    return out
  end

  vim.api.nvim_create_user_command("LatexNew", function(opts)
    if opts.args == "" then
      notify('Usage: :LatexNew {target_dir} [name="Title"] [author="Your Name"] [template="/path"]', vim.log.levels.ERROR)
      return
    end
    local target, rest = opts.args:match("^(%S+)%s*(.*)$")
    local kv = parse_kv(rest or "")

    local template_dir = kv.template or fn.expand("~/.config/latex-templates/latex-template-pack")
    if not exists(template_dir) then
      notify("Template dir not found: " .. template_dir, vim.log.levels.ERROR)
      return
    end

    local abs_target = target:match("^/") and target or join(fn.getcwd(), target)
    if exists(abs_target) and not is_dir(abs_target) then
      notify("Target exists and is not a directory: " .. abs_target, vim.log.levels.ERROR)
      return
    end
    mkdir_p(abs_target)

    local base = vim.fs.basename(abs_target)
    local author = (fn.systemlist("git config user.name")[1] or ""):gsub("^%s*(.-)%s*$","%1")
    local vars = {
      PROJECT = kv.name or base,
      AUTHOR  = kv.author or (author ~= "" and author or "Author"),
      DATE    = os.date("%Y-%m-%d"),
      YEAR    = os.date("%Y"),
    }

    copy_with_subst(template_dir, abs_target, vars)

    notify("Project created at: " .. abs_target)
    local main = join(abs_target, "main.tex")
    if exists(main) then vim.cmd.edit(main) else vim.cmd.edit(abs_target) end
  end, { nargs = "+", complete = "dir", desc = "Create a LaTeX project from your template pack." })
end

return M
