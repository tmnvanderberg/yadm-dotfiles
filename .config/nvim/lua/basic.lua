-- use spacebar as <leader>
vim.g.mapleader = ' '

-- enable mouse, sometimes.
vim.cmd [[set mouse=a]]

-- enable line numbers
vim.wo.number = true

-- enable autocomplete
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

-- always show sign column
vim.cmd [[set signcolumn=no]]

-- disable diagnostics inline (use <space>e instead)
vim.diagnostic.config({
  virtual_text = false,
})
