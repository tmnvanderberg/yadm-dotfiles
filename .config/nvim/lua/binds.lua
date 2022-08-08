require('map')

-- init leap with default maps
require('leap').set_default_keymaps()

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
	":Fern . -drawer -toggle -width=60<CR>",
	{ silent = true }
)

-- open file browser cwd with focus on current buffer
Map(
	"n",
	"<Leader>nf",
	":Fern . -drawer -width=60 -reveal=%<CR>",
	{ silent = true }
)

-- reveal the config
Map(
	"n",
	"<Leader>ve",
	":Fern ~/.config/nvim -drawer -width=60 -reveal=~/.config/nvim/init.vim<CR>",
	{ silent = true }
)

-- toggle blankline
Map(
	"n",
	"<Leader>bl",
	":IndentBlanklineToggle!<CR>",
	{ silent = true }
)
