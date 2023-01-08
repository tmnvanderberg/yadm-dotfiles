local fn = vim.fn
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
local packer_bootstrap
if fn.empty(fn.glob(install_path)) > 0 then
	packer_bootstrap = fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
end

return require('packer').startup(function(use)
	-- Packer can manage itself (requires packer to be installed initially)
	use 'wbthomason/packer.nvim'

	-- GIT --
	use 'tpope/vim-fugitive'
	use 'junegunn/gv.vim'

	-- NAV --
	use { 'junegunn/fzf', run = './install --bin', }
	use { 'ibhagwan/fzf-lua',
		-- optional for icon support
		requires = { 'kyazdani42/nvim-web-devicons' },
	}

	-- Unless you are still migrating, remove the deprecated commands from v1.x
	vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])
	use {
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v2.x",
		requires = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
			"MunifTanjim/nui.nvim",
		}
	}

	-- LANGUAGE --
	use 'williamboman/mason.nvim' -- auto-install language servers
	use 'williamboman/mason-lspconfig.nvim' -- lspconfig / mason bridge
	use 'neovim/nvim-lspconfig' -- Collection of configurations for built-in LSP client
	use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
	use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
	use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
	use 'L3MON4D3/LuaSnip' -- Snippets plugin
	use 'solarnz/thrift.vim' -- thrift syntax
	use 'MTDL9/vim-log-highlighting' -- generic log hightighter
	use 'kergoth/vim-bitbake' -- syntax for bb files
	use 'nathom/filetype.nvim' -- customize filetype detection
	use {
	  "folke/trouble.nvim",
	  requires = "kyazdani42/nvim-web-devicons",
	  config = function()
	    require("trouble").setup { }
	  end
	}
	use 'LnL7/vim-nix' -- nix language support

	-- ADDONS --
	use 'jpalardy/vim-slime' -- sends text to tmux panes
	use 'nvim-lualine/lualine.nvim' -- lightweight status line
	use 'tpope/vim-commentary' -- comment and uncomment things
	use 'nvim-lua/plenary.nvim' -- library of lua functions, required by spectre
	use 'nvim-pack/nvim-spectre' -- regex search & replace in project
	use 'tpope/vim-surround' -- parentheses plugin
	use 'tpope/vim-sleuth' -- detect indent sizes
	use 'tpope/vim-abolish' -- cool replace

	-- THEME
	use 'sainnhe/gruvbox-material'
	use 'https://gitlab.com/protesilaos/tempus-themes-vim.git'
	use 'projekt0n/github-nvim-theme'

	-- BOOTSTRAP
	if packer_bootstrap then
		require('packer').sync()
	end
end)
