require('map')

-- fuzzy search for filenames
map(
	"n", 
	"<C-p>", 
	":FzfLua files<CR>", 
	{ silent = true }
)

-- fuzzy search vim file history
map(
	"n", 
	"<Leader>b", 
	":FzfLua oldfiles<CR>", 
	{ silent = true }
)

-- fuzzy search vim marks
map(
	"n", 
	"<Leader>m", 
	":FzfLua marks<CR>", 
	{ silent = true }
)

-- grep for the current word
map(
	"n", 
	"<Leader>F", 
	":FzfLua grep_cword<CR>", 
	{ silent = true }
)

-- grep for the current visual selection
map(
	"v", 
	"<Leader>F", 
	":FzfLua grep_visual<CR>", 
	{ silent = true }
)

-- grep for text in files
map(
	"n", 
	"<Leader>lf", 
	":FzfLua live_grep_resume<CR>", 
	{ silent = true }
)

-- search filenames for current word
map(
	"n", 
	"<Leader><C-P>", 
	":FzfLua files <C-R><C-W><CR>", 
	{ silent = true }
)
