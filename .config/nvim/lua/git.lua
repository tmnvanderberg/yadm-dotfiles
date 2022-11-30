require('map')

vim.g.merginal_windowWidth = 50

-- main git interface of fugitive
Map(
	"n",
	"<Leader>G",
	":G<CR>",
	{ silent = true }
)

-- cherry-pick current word
Map(
	"n",
	"<Leader>t",
	":G cherry-pick <C-R><C-W><CR>",
	{ silent = true }
)

-- List and manipulate branches
Map(
	"n",
	"<Leader>M",
	":Merginal<CR>",
	{ silent = true }
)
