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
	":Neotree source=filesystem position=left<CR>",
	{ silent = true }
)

-- open file browser cwd with focus on current buffer
Map(
	"n",
	"<Leader>nf",
	":Neotree source=filesystem reveal=true position=left<CR>",
	{ silent = true }
)

-- reveal the config
Map(
	"n",
	"<Leader>ve",
	":Neotree source=filesystem position=left dir=/home/timon/.config/nvim/lua/<CR>",
	{ silent = true }
)

-- show buffers
Map(
	"n",
	"<Leader>nb",
	":Neotree source=buffers position=right<CR>",
	{ silent = true }
)

-- show git
Map(
	"n",
	"<Leader>ng",
	":Neotree source=git_status position=right<CR>",
	{ silent = true }
)

-- toggle blankline
Map(
	"n",
	"<Leader>bl",
	":IndentBlanklineToggle!<CR>",
	{ silent = true }
)

-- use Alt-R as C-R replacement for terminal buffers (copied from FzfLua issue tracker)
vim.keymap.set('t', '<M-r>', [['<C-\><C-N>"'.nr2char(getchar()).'pi']], { expr = true })

