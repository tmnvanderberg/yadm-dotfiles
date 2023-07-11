-- use spacebar as <leader>
vim.g.mapleader = ' '

-- enable mouse, sometimes.
vim.cmd [[set mouse=a]]

-- enable line numbers
vim.wo.number = true

-- enable autocomplete
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

-- always show sign colum
vim.cmd [[set signcolumn=no]]

-- disable diagnostics inline (use <space>e instead)
vim.diagnostic.config({
  virtual_text = false,
})

-- set tab width
vim.cmd [[set tabstop=2]]

-- use system clipboard by default
vim.cmd [[set clipboard=unnamedplus]]

-- copy current file path
vim.api.nvim_create_user_command("Cppath", function()
    local path = vim.fn.expand("%:p")
    vim.fn.setreg("+", path)
    vim.notify('Copied "' .. path .. '" to the clipboard!')
end, {}) 
