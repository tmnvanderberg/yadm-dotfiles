-- use spacebar as <leader>
vim.g.mapleader = ' '

local options = {
  backup = false,                          -- creates a backup file
  clipboard = "unnamedplus",               -- allows neovim to access the system clipboard
  cmdheight = 2,                           -- more space in the neovim command line for displaying messages
  completeopt = { "menuone", "noselect" }, -- mostly just for cmp
  conceallevel = 0,                        -- so that `` is visible in markdown files
  fileencoding = "utf-8",                  -- the encoding written to a file
  hidden = true,                           -- required to keep multiple buffers and open multiple buffers
  hlsearch = true,                         -- highlight all matches on previous search pattern
  ignorecase = true,                       -- ignore case in search patterns
  mouse = "a",                             -- allow the mouse to be used in neovim
  pumheight = 10,                          -- pop up menu height
  showmode = false,                        -- we don't need to see things like -- INSERT -- anymore
  showtabline = 2,                         -- always show tabs
  smartcase = true,                        -- smart case
  smartindent = true,                      -- make indenting smarter again
  splitbelow = true,                       -- force all horizontal splits to go below current window
  splitright = true,                       -- force all vertical splits to go to the right of current window
  swapfile = false,                        -- creates a swapfile
  termguicolors = true,                    -- set term gui colors (most terminals support this)
  timeoutlen = 300,                        -- time to wait for a mapped sequence to complete (in milliseconds)
  undofile = true,                         -- enable persistent undo
  updatetime = 300,                        -- faster completion (4000ms default)
  writebackup = false,                     -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
  expandtab = false,                        -- convert tabs to spaces
  shiftwidth = 2,                          -- the number of spaces inserted for each indentation
  tabstop = 2,                             -- insert 2 spaces for a tab
  cursorline = false,                       -- highlight the current line
  cursorcolumn = false,
  number = true,                           -- set numbered lines
  relativenumber = false,                  -- set relative numbered lines
  numberwidth = 4,                         -- set number column width to 2 {default 4}
  signcolumn = "yes",                      -- always show the sign column, otherwise it would shift the text each time
  wrap = true,                             -- display lines as one long line
  scrolloff = 8,
  sidescrolloff = 8,
  foldmethod = "syntax",
  foldlevelstart = 99,
  linebreak = true
}

vim.opt.shortmess:append "c"

for k, v in pairs(options) do
  vim.opt[k] = v
end

vim.opt.whichwrap:append("<,>,[,],h,l")
vim.opt.colorcolumn = "100"

-- disable diagnostics inline (use <space>e instead)
vim.diagnostic.config({
  virtual_text = false,
})

-- copy current file path
vim.api.nvim_create_user_command("Cppath", function()
    local path = vim.fn.expand("%:p")
    vim.fn.setreg("+", path)
    vim.notify('Copied "' .. path .. '" to the clipboard!')
end, {})

local function get_visual_range()
  local srow, scol = unpack(vim.api.nvim_buf_get_mark(0, "<"))
  local erow, ecol = unpack(vim.api.nvim_buf_get_mark(0, ">"))
  if srow == 0 or erow == 0 then
    return nil
  end

  if srow > erow or (srow == erow and scol > ecol) then
    srow, erow = erow, srow
    scol, ecol = ecol, scol
  end

  local end_line = vim.api.nvim_buf_get_lines(0, erow - 1, erow, false)[1] or ""
  local end_col = math.min(ecol + 1, #end_line)

  return {
    srow = srow - 1,
    scol = scol,
    erow = erow - 1,
    ecol = end_col,
  }
end

local function get_text_in_range(range)
  return vim.api.nvim_buf_get_text(0, range.srow, range.scol, range.erow, range.ecol, {})
end

local function replace_text_in_range(range, text)
  local lines = vim.split(text or "", "\n", { plain = true })
  vim.api.nvim_buf_set_text(0, range.srow, range.scol, range.erow, range.ecol, lines)
end

vim.api.nvim_create_user_command("OpenAIRewrite", function()
  local api_key = vim.env.OPENAI_API_KEY
  if not api_key or api_key == "" then
    vim.notify("OPENAI_API_KEY is not set", vim.log.levels.ERROR)
    return
  end

  local range = get_visual_range()
  if not range then
    vim.notify("Select text in visual mode before running :OpenAIRewrite", vim.log.levels.WARN)
    return
  end

  local selection = table.concat(get_text_in_range(range), "\n")
  if selection == "" then
    vim.notify("Selection is empty", vim.log.levels.WARN)
    return
  end

  local instruction = vim.fn.input("Rewrite instruction: ")
  if instruction == nil or instruction == "" then
    vim.notify("Rewrite canceled (no instruction provided)", vim.log.levels.INFO)
    return
  end

  local payload = vim.json.encode({
    model = vim.env.OPENAI_MODEL or "gpt-4.1-mini",
    messages = {
      { role = "system", content = "You rewrite selected text based on user instructions. Return only the rewritten text." },
      {
        role = "user",
        content = "Instruction:\n"
          .. instruction
          .. "\n\nSelected text:\n"
          .. selection,
      },
    },
  })

  vim.notify("Sending selection to OpenAI...", vim.log.levels.INFO)

  vim.system({
    "curl",
    "-sS",
    "https://api.openai.com/v1/chat/completions",
    "-H",
    "Content-Type: application/json",
    "-H",
    "Authorization: Bearer " .. api_key,
    "-d",
    payload,
  }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("OpenAI request failed: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
        return
      end

      local ok, decoded = pcall(vim.json.decode, result.stdout or "")
      if not ok then
        vim.notify("Failed to parse OpenAI response", vim.log.levels.ERROR)
        return
      end

      local content = decoded
        and decoded.choices
        and decoded.choices[1]
        and decoded.choices[1].message
        and decoded.choices[1].message.content

      if type(content) ~= "string" or content == "" then
        vim.notify("OpenAI returned empty content", vim.log.levels.ERROR)
        return
      end

      replace_text_in_range(range, content)
      vim.notify("Selection rewritten", vim.log.levels.INFO)
    end)
  end)
end, {})

-- vimwiki (and some plugins) still call this deprecated helper in 0.11+
if vim.tbl_add_reverse_lookup then
  vim.tbl_add_reverse_lookup = function(tbl)
    for k, v in pairs(tbl) do
      if tbl[v] == nil then
        tbl[v] = k
      end
    end
    return tbl
  end
end

-- compatibility for deprecated vim.tbl_islist
if vim.tbl_islist then
  vim.tbl_islist = vim.islist
end

-- all the whitesp chrs:
vim.opt.listchars = {
  eol = "¬",
  tab = ">·",
  trail = "~",
  extends = ">",
  precedes = "<",
  space = "␣",
}

-- increase limit for Flog
vim.g.flog_default_opts = {
    max_count = 2000000,
    merges = 100,
    date = 'short'
}

vim.g.maplocalleader = ','
vim.g.jira_definition_of_done_field = "customfield_10100"
vim.g.jira_story_points_field = "customfield_10057"

-- Tell Tree-sitter to treat vimwiki buffers as markdown
vim.treesitter.language.register("markdown", { "vimwiki", "vimwiki.markdown" })

-- Open Vimwiki index on startup when no files were passed on the CLI.
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    if vim.fn.argc() ~= 0 then
      return
    end
    vim.schedule(function()
      pcall(vim.cmd, "VimwikiIndex")
    end)
  end,
})
