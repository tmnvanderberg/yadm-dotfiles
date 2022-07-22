return require('packer').startup(function()
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
	use 'easymotion/vim-easymotion' -- nagivate buffers with hints

	-- LANGUAGE --
	use 'neovim/nvim-lspconfig' -- Collection of configurations for built-in LSP client
	use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
	use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
	use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
	use 'L3MON4D3/LuaSnip' -- Snippets plugin
	use 'rhysd/vim-clang-format'

	-- ADDONS --
	use 'junegunn/vim-peekaboo' -- register pane
	use 'jpalardy/vim-slime'-- sends text to tmux panes
	use 'nvim-lualine/lualine.nvim' -- lightweight status line

	-- THEME
	use 'junegunn/seoul256.vim' -- excellent color scheme from creator of fzf
end)

