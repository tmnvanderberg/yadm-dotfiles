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
	use 'easymotion/vim-easymotion' -- nagivate buffers with hints

	-- LANGUAGE --
	use 'williamboman/nvim-lsp-installer' -- auto-install language servers
	use 'neovim/nvim-lspconfig' -- Collection of configurations for built-in LSP client
	use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
	use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
	use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
	use 'L3MON4D3/LuaSnip' -- Snippets plugin
	use({
		"https://git.sr.ht/~whynothugo/lsp_lines.nvim",
		config = function()
			require("lsp_lines").setup()
		end,
	})

	-- ADDONS --
	use 'junegunn/vim-peekaboo' -- register pane
	use 'jpalardy/vim-slime'-- sends text to tmux panes
	use 'nvim-lualine/lualine.nvim' -- lightweight status line

	-- THEME
	use 'junegunn/seoul256.vim' -- excellent color scheme from creator of fzf

	-- BOOTSTRAP
	if packer_bootstrap then
		require('packer').sync()
	end
end)
