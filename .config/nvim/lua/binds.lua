require('map')

-- remove highlight after search
map(
	"n", 
	"<Leader>u", 
	":nohl<CR>",
	{ silent = true }
)

-- only show current split, closing others
map( 
	"n", 
	"<Leader>i", 
	":only<CR>",
	{ silent = true }
)
