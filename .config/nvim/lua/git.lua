require('map')

-- main git interface of fugitive
Map(
	"n",
	"<Leader>G",
	":G<CR>",
	{ silent = true, noremap = true }
)

-- cherry-pick current word
Map(
	"n",
	"<Leader>t",
	":G cherry-pick <C-R><C-W><CR>",
	{ silent = true, noremap = true }
)
