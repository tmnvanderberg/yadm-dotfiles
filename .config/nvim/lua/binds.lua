require('map')

-- Switch header/source
Map(
	"n",
	"<C-h>",
	":ClangdSwitchSourceHeader<CR>",
	{ silent = true, noremap = true }
)

-- remove highlight after search
Map(
  "n",
  "<Leader>u",
  ":nohl<CR>",
  { silent = true, noremap = true }
)

-- only show current split, closing others
Map(
  "n",
  "<Leader>i",
  ":only<CR>",
  { silent = true, noremap = true }
)

-- open file browser cwd with focus on current buffer
Map(
  "n",
  "<Leader>e",
  ":NvimTreeFindFile<CR>",
  { silent = true, noremap = true }
)

-- Copy File path relative to working directory
Map(
  "n",
  "<Leader>cf",
  ":let @+=fnamemodify(expand('%:p'), ':~:.')<CR>",
  { silent = false }
)

-- Open a Terminal in the directory of the current file
Map(
  "n",
  "<Leader>k",
  ":silent !konsole --workdir %:p:h --new-tab &<CR><CR>",
  { silent = false }
)

function OpenKonsoleTab()
  local current_dir = vim.fn.getcwd()
  local command = 'konsole --new-tab --workdir "' .. current_dir .. '"'
  vim.fn.jobstart(command)
end

-- Open a Terminal in the current Working directory
Map(
  "n",
  "<Leader>tk",
  ":lua OpenKonsoleTab()<CR>",
  { silent = false }
)

function CopyFP()
  local linenr = vim.api.nvim_win_get_cursor(0)[1]
  local filepath = vim.api.nvim_buf_get_name(0)
  local line_number_str = string.format("-%d", linenr)
  local full_filepath = filepath .. line_number_str
  vim.fn.setreg("+", full_filepath)
end

Map(
  "n",
  "<Leader>fp",
  ":lua CopyFP()<CR>",
  { silent = false }
)

Map(
  "n",
  "<Leader>l",
  ":set list!<CR>",
  { silent = false }
)

-- use Alt-R as C-R replacement for terminal buffers
vim.keymap.set('t', '<M-r>', [['<C-\><C-N>"'.nr2char(getchar()).'pi']], { expr = true })
