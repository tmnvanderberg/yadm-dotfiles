require('map')

vim.g.merginal_windowWidth = 50

-- main git interface of fugitive
map(
	"n", 
	"<Leader>G", 
	":G<CR>", 
	{ silent = true }
)

-- git graph of all branches
map(
	"n", 
	"<Leader>gag", 
	":G log --all --graph --pretty=format:\"[%h] %<(140,trunc)%s [%ad] %><(13,trunc)(%an) %d\" --date=short --expand-tabs <CR>", 
	{ silent = true }
)

-- git graph of current branch
map(
	"n", 
	"<Leader>gg",
	":G log --graph --pretty=format:\"[%h] %<(140,trunc)%s [%ad] %><(13,trunc)(%an) %d\" --date=short --expand-tabs <CR>",
	{ silent = true }
)

-- cherry-pick current word
map(
	"n", 
	"<Leader>t",
	":G cherry-pick <C-R><C-W><CR>",
	{ silent = true }
)

-- file history
map(
	"n", 
	"<Leader>t",
	":G log -- %<CR>",
	{ silent = true }
)

-- List and manipulate branches
map(
	"n", 
	"<Leader>M",
	":Merginal<CR>",
	{ silent = true }
)
