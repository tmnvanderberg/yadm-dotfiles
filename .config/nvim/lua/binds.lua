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
