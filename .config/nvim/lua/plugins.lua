local fn = vim.fn
local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
local packer_bootstrap
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

return require('packer').startup(function(use)
	-- Packer can manage itself (requires packer to be installed initially)
	use 'wbthomason/packer.nvim'

	-- GIT --
	use 'tpope/vim-fugitive'
	use 'idanarye/vim-merginal'
	use 'airblade/vim-gitgutter'

	-- NAV --
	use { 'junegunn/fzf', run = './install --bin', }
	use { 'ibhagwan/fzf-lua',
	  -- optional for icon support
	  requires = { 'kyazdani42/nvim-web-devicons' }
	}
	use 'lambdalisue/fern.vim' -- files browser
	use 'lambdalisue/fern-git-status.vim' -- git status for fern
	use 'ggandor/leap.nvim'

	-- LANGUAGE --
	use 'williamboman/mason.nvim' -- auto-install language servers
	use 'williamboman/mason-lspconfig.nvim' -- lspconfig / mason bridge
	use 'neovim/nvim-lspconfig' -- Collection of configurations for built-in LSP client
	use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
	use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
	use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
	use 'L3MON4D3/LuaSnip' -- Snippets plugin
	-- use 'nvim-treesitter/nvim-treesitter' -- treesitter parses code & providers concrete syntax tree
	use 'solarnz/thrift.vim' -- thrift syntax
	use 'MTDL9/vim-log-highlighting' -- generic log hightighter
	use 'kergoth/vim-bitbake'

	-- ADDONS --
	use 'junegunn/vim-peekaboo' -- register pane
	use 'jpalardy/vim-slime'-- sends text to tmux panes
	use 'nvim-lualine/lualine.nvim' -- lightweight status line
	use 'vimwiki/vimwiki' -- wiki inside vim
	use 'tpope/vim-commentary' -- comment and uncomment things
	use 'lukas-reineke/indent-blankline.nvim' -- indentation lines
	use 'nvim-lua/plenary.nvim' -- library of lua functions, required by spectre
	use 'nvim-pack/nvim-spectre' -- regex search & replace in project
	use 'tpope/vim-surround' -- parentheses plugin
	use 'NMAC427/guess-indent.nvim'
	use 'chentoast/marks.nvim'

	-- THEME
	use 'junegunn/seoul256.vim' -- excellent color scheme from creator of fzf
	use 'sainnhe/everforest'
	use 'marko-cerovac/material.nvim'
	use 'Th3Whit3Wolf/space-nvim'
	use 'andersevenrud/nordic.nvim'
	use 'sainnhe/gruvbox-material'
	use 'phha/zenburn.nvim'
	use 'stevearc/dressing.nvim'

	-- BOOTSTRAP
	if packer_bootstrap then
		require('packer').sync()
	end
end)

