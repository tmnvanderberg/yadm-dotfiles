local map = require('map')

map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
	{ silent = true }
)

map(
  "n",
  "<Leader>w",
  ":lua require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') }})<CR>",
  { silent = true }
)

map(
  "v",
  "<Leader>w",
  ":lua require('grug-far').with_visual_selection()<CR>",
  { silent = true }
)
