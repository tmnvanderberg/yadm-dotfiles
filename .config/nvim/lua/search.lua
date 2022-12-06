require('map')

-- Fuzzy search for anything, really. I used to have shortcuts for different searches,
-- but this has less mental overhead and allows you to search with 1 or 2 letters. Only the most common searches have their own keybind.
Map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
	{ silent = true }
)

-- search files
Map(
	"n",
	"<C-f>",
	":FzfLua files<CR>",
	{ silent = true }
)

-- search buffers
Map(
	"n",
	"<C-l>",
	":FzfLua buffers<CR>",
	{ silent = true }
)

-- grep
Map(
	"n",
	"<C-g>",
	":FzfLua live_grep<CR>",
	{ silent = true }
)

-- search with spectre
Map(
	"n",
	"<Leader><C-R>",
	"<cmd>lua require('spectre').open()<CR>",
	{ silent = true }
)
