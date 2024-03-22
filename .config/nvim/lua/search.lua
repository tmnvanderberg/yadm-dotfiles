require('map')

-- Fuzzy search for anything, really.
Map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
	{ silent = true, noremap = true }
)
