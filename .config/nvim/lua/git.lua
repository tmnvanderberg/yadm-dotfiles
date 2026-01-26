local map = require('map')

-- main git interface of fugitive
map(
	"n",
	"<Leader>G",
	":Neogit<CR>",
	{ silent = true }
)

-- cherry-pick current word
map(
	"n",
	"<Leader>t",
	":G cherry-pick <C-R><C-W><CR>",
	{ silent = true }
)
