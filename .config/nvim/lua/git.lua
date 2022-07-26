require('map')

vim.g.merginal_windowWidth = 50

-- main git interface of fugitive
Map(
	"n",
	"<Leader>G",
	":G<CR>",
	{ silent = true }
)

-- git graph of all branches
Map(
	"n",
	"<Leader>gag",
	":G log --all --graph --pretty=format:\"[%h] %<(140,trunc)%s [%ad] %><(13,trunc)(%an) %d\" --date=short --expand-tabs <CR>",
	{ silent = true }
)

-- git graph of current branch
Map(
	"n",
	"<Leader>gg",
	":G log --graph --pretty=format:\"[%h] %<(140,trunc)%s [%ad] %><(13,trunc)(%an) %d\" --date=short --expand-tabs <CR>",
	{ silent = true }
)

-- current file commits
Map(
	"n",
	"<Leader>gfg",
	":G log -- %<CR>", 
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
