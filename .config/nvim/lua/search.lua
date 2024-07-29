require('map')

-- Fuzzy search for anything, really.
Map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
	{ silent = true, noremap = true }
)

Map(
	"n",
	"<C-l>",
	":FzfLua buffers<CR>",
	{ silent = true, noremap = true }
)

