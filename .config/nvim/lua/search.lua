require('map')

Map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
	{ silent = true, noremap = true }
)

Map(
  "n",
  "<Leader>w",
  ":lua require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') }})<CR>",
  { silent = true, noremap = true }
)

Map(
  "v",
  "<Leader>w",
  ":lua require('grug-far').with_visual_selection()<CR>",
  { silent = true, noremap = true }
)
