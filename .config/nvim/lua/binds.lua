require('map')

-- remove highlight after search
Map(
	"n",
	"<Leader>u",
	":nohl<CR>",
	{ silent = true }
)

-- only show current split, closing others
Map(
	"n",
	"<Leader>i",
	":only<CR>",
	{ silent = true }
)

-- open file browser cwd
Map(
	"n",
	"<Leader>nh",
	":Fern .<CR>",
	{ silent = true }
)

-- open file browser cwd
Map(
	"n",
	"<Leader>nf",
	":Fern .<CR>",
	{ silent = true }
)
