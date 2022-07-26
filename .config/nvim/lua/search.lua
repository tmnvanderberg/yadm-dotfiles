require('map')

-- fuzzy search for filenames
Map(
	"n",
	"<C-p>",
	":FzfLua files<CR>",
	{ silent = true }
)

-- fuzzy search vim file history
Map(
	"n",
	"<Leader>b",
	":FzfLua oldfiles<CR>",
	{ silent = true }
)

-- fuzzy search vim marks
Map(
	"n",
	"<Leader>m",
	":FzfLua marks<CR>",
	{ silent = true }
)

-- grep for the current word
Map(
	"n",
	"<Leader>F",
	":FzfLua grep_cword<CR>",
	{ silent = true }
)

-- grep for the current visual selection
Map(
	"v",
	"<Leader>F",
	":FzfLua grep_visual<CR>",
	{ silent = true }
)

-- grep for text in files
Map(
	"n",
	"<Leader>lf",
	":FzfLua live_grep_resume<CR>",
	{ silent = true }
)

-- search filenames for current word
Map(
	"n",
	"<Leader><C-P>",
	":FzfLua files <C-R><C-W><CR>",
	{ silent = true }
)

-- search buffers
Map(
	"n",
	"<Leader>l",
	":FzfLua buffers <CR>",
	{ silent = true }
)

-- search with spectre
Map(
	"n",
	"<Leader><C-R>",
	"<cmd>lua require('spectre').open()<CR>",
	{ silent = true }
)
