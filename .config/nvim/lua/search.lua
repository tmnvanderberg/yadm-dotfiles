local map = require('map')

map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
	{ silent = true }
)

map("n", "<Leader>w", function()
  require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') } })
end, { silent = true })

map("v", "<Leader>w", function()
  require('grug-far').with_visual_selection()
end, { silent = true })
