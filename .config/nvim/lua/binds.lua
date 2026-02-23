local map = require('map')

-- remove highlight after search
map(
  "n",
  "<Leader>u",
  ":nohl<CR>",
  { silent = true }
)

-- open vim wiki index
map(
  "n",
  "<Leader>ow",
  ":VimwikiIndex<CR>",
  { silent = true }
)
-- only show current split, closing others
map(
  "n",
  "<Leader>i",
  ":only<CR>",
  { silent = true }
)

-- open file browser cwd with focus on current buffer
map(
  "n",
  "<Leader>e",
  ":NvimTreeFindFile<CR>",
  { silent = true }
)

-- Copy File path relative to working directory
map(
  "n",
  "<Leader>cf",
  ":let @+=fnamemodify(expand('%:p'), ':~:.')<CR>",
  { silent = false }
)

-- Open a Terminal in the directory of the current file
map(
  "n",
  "<Leader>k",
  ":silent !konsole --workdir %:p:h --new-tab &<CR><CR>",
  { silent = false }
)

local function open_konsole_tab()
  local current_dir = vim.fn.getcwd()
  local command = 'konsole --new-tab --workdir "' .. current_dir .. '"'
  vim.fn.jobstart(command)
end

-- Open a Terminal in the current Working directory
map("n", "<Leader>tk", open_konsole_tab, { silent = false })

local function copy_fp()
  local linenr = vim.api.nvim_win_get_cursor(0)[1]
  local filepath = vim.api.nvim_buf_get_name(0)
  local line_number_str = string.format("-%d", linenr)
  local full_filepath = filepath .. line_number_str
  vim.fn.setreg("+", full_filepath)
end

map("n", "<Leader>fp", copy_fp, { silent = false })

map(
  "n",
  "<Leader>l",
  ":set list!<CR>",
  { silent = false }
)

-- use Alt-R as C-R replacement for terminal buffers
vim.keymap.set('t', '<M-r>', [['<C-\><C-N>"'.nr2char(getchar()).'pi']], { expr = true })

-- rewrite visual selection using OpenAI
map("v", "<Leader>ar", ":<C-u>OpenAIRewrite<CR>", { silent = true })

-- LaTeX workflow (vimtex)
local function ensure_tex_buffer_has_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    return true
  end

  local preview_dir = vim.fn.stdpath("state") .. "/latex-preview"
  vim.fn.mkdir(preview_dir, "p")
  local temp_path = string.format(
    "%s/buffer-%d-%s.tex",
    preview_dir,
    bufnr,
    os.date("%Y%m%d-%H%M%S")
  )
  local ok = pcall(vim.api.nvim_buf_set_name, bufnr, temp_path)
  if not ok then
    vim.notify("Could not assign temporary .tex filename to current buffer", vim.log.levels.ERROR)
    return false
  end
  return true
end

local function vimtex_compile_current_buffer()
  if not ensure_tex_buffer_has_file() then
    return
  end
  vim.cmd("silent write!")
  vim.cmd("VimtexCompile")
end

local function vimtex_view_current_buffer()
  if not ensure_tex_buffer_has_file() then
    return
  end
  vim.cmd("silent write!")
  vim.cmd("VimtexView")
end

map("n", "<Leader>ll", vimtex_compile_current_buffer, { silent = true })
map("n", "<Leader>lv", vimtex_view_current_buffer, { silent = true })
map("n", "<Leader>lk", ":VimtexStop<CR>", { silent = true })
map("n", "<Leader>le", ":VimtexErrors<CR>", { silent = true })
