return require('packer').startup(function()
	-- Packer can manage itself
	use 'wbthomason/packer.nvim'
	-- vim-fugitive is a plugin to use Git in vim
	use 'tpope/vim-fugitive'
	-- fuzzy search
	use { 'ibhagwan/fzf-lua',
		requires = { 'kyazdani42/nvim-web-devicons' }
	}
end)

